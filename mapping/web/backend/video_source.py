"""拉取小车摄像头 MJPEG/HTTP 视频流。"""

from __future__ import annotations

import logging
import re
import threading
import time
from typing import Optional
from urllib.parse import urljoin

import cv2
import numpy as np

logger = logging.getLogger("video_source")

_STREAM_HINTS = ("stream", "video", "mjpeg", "cam", "action", "feed")


def discover_stream_urls(page_url: str) -> list[str]:
    """从 index2 等 HTML 页面解析可能的 MJPEG 地址。"""
    try:
        import httpx

        with httpx.Client(timeout=8.0, follow_redirects=True) as client:
            resp = client.get(page_url)
            if resp.status_code != 200:
                logger.warning("discover page %s -> HTTP %s", page_url, resp.status_code)
                return []
            html = resp.text
    except Exception as exc:
        logger.warning("discover page failed %s: %s", page_url, exc)
        return []

    found: list[str] = []
    seen: set[str] = set()
    for match in re.finditer(r"""(?:src|href)\s*=\s*["']([^"']+)["']""", html, re.I):
        raw = match.group(1).strip()
        if not raw or raw.startswith("data:"):
            continue
        full = urljoin(page_url, raw)
        low = full.lower()
        if any(h in low for h in _STREAM_HINTS) or low.endswith((".mjpg", ".mjpeg")):
            if full not in seen:
                seen.add(full)
                found.append(full)
    if found:
        logger.info("discovered %s stream url(s) from %s", len(found), page_url)
    return found


class VideoSource:
    def __init__(
        self,
        urls: list[str],
        discover_page: Optional[str] = None,
        reconnect_sec: float = 2.0,
    ) -> None:
        self.urls = list(urls)
        self.discover_page = discover_page
        self.reconnect_sec = reconnect_sec
        self._cap: Optional[cv2.VideoCapture] = None
        self._url_idx = 0
        self._frame: Optional[np.ndarray] = None
        self._lock = threading.Lock()
        self._running = False
        self._thread: Optional[threading.Thread] = None
        self.connected = False
        self.active_url: Optional[str] = None
        self.last_error: str = ""

    def refresh_urls(self, extra: list[str]) -> None:
        merged: list[str] = []
        seen: set[str] = set()
        for u in extra + self.urls:
            if u and u not in seen:
                seen.add(u)
                merged.append(u)
        self.urls = merged

    def start(self) -> None:
        if self.discover_page:
            discovered = discover_stream_urls(self.discover_page)
            if discovered:
                self.refresh_urls(discovered)
        if self._thread and self._thread.is_alive():
            return
        self._running = True
        self._thread = threading.Thread(target=self._loop, daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._running = False
        if self._cap:
            self._cap.release()
            self._cap = None
        self.connected = False
        self.active_url = None

    def get_frame(self) -> Optional[np.ndarray]:
        with self._lock:
            if self._frame is None:
                return None
            return self._frame.copy()

    def _loop(self) -> None:
        while self._running:
            if self._cap is None or not self._cap.isOpened():
                self._open_next()
                if self._cap is None:
                    time.sleep(self.reconnect_sec)
                    continue
            ok, frame = self._cap.read()
            if not ok or frame is None:
                self.last_error = f"read failed from {self.active_url}"
                logger.warning("frame read failed, reconnect (%s)", self.active_url)
                self._cap.release()
                self._cap = None
                self.connected = False
                self.active_url = None
                time.sleep(self.reconnect_sec)
                continue
            with self._lock:
                self._frame = frame
            self.connected = True
            self.last_error = ""

    def _open_next(self) -> None:
        if not self.urls:
            self.last_error = "no stream urls configured"
            return
        for _ in range(len(self.urls)):
            url = self.urls[self._url_idx % len(self.urls)]
            self._url_idx += 1
            logger.info("try video url %s", url)
            cap = cv2.VideoCapture(url)
            if cap.isOpened():
                ok, frame = cap.read()
                if ok and frame is not None:
                    self._cap = cap
                    self.active_url = url
                    with self._lock:
                        self._frame = frame
                    self.connected = True
                    logger.info("video opened %s", url)
                    return
                cap.release()
                self.last_error = f"opened but no frame: {url}"
                logger.warning(self.last_error)
                continue
            cap.release()
            self.last_error = f"cannot open: {url}"
        self._cap = None
