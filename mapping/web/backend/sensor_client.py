"""连接小车 WebSocket :6602，喂给 SLAM。"""

from __future__ import annotations

import asyncio
import logging
import time
from typing import Callable, Optional

import websockets

from .sensor_protocol import OdomFrame, ScanFrame, parse_frames
from .slam_engine import SlamEngine

logger = logging.getLogger("sensor_client")


class SensorClient:
    def __init__(
        self,
        ws_url: str,
        slam: SlamEngine,
        on_connect: Optional[Callable[[bool], None]] = None,
    ) -> None:
        self.ws_url = ws_url
        self.slam = slam
        self.on_connect = on_connect
        self._running = False
        self._task: Optional[asyncio.Task] = None
        self.connected = False
        self.has_scan = False
        self.last_error = ""
        self._last_scan_time = 0.0

    def start(self) -> None:
        if self._task and not self._task.done():
            return
        self._running = True
        self._task = asyncio.create_task(self._loop())

    def stop(self) -> None:
        self._running = False
        if self._task:
            self._task.cancel()

    async def _loop(self) -> None:
        buffer = ""
        while self._running:
            try:
                logger.info("connecting sensor ws %s ...", self.ws_url)
                async with websockets.connect(
                    self.ws_url,
                    ping_interval=20,
                    ping_timeout=60,
                    close_timeout=5,
                ) as ws:
                    self.connected = True
                    self.last_error = ""
                    if self.on_connect:
                        self.on_connect(True)
                    logger.info("sensor ws connected %s", self.ws_url)
                    async for message in ws:
                        buffer += message
                        frames, buffer = parse_frames(buffer)
                        for frame in frames:
                            if isinstance(frame, ScanFrame):
                                if not self.has_scan:
                                    self.has_scan = True
                                    logger.info("first @SCAN received from car")
                                self._last_scan_time = time.time()
                                self.slam.ingest_scan(frame)
                            elif isinstance(frame, OdomFrame):
                                self.slam.ingest_odom(frame)
            except asyncio.CancelledError:
                break
            except Exception as exc:
                self.last_error = str(exc)
                logger.warning("sensor ws error: %s — retry in 2s", exc)
                self.connected = False
                self.has_scan = False
                if self.on_connect:
                    self.on_connect(False)
                await asyncio.sleep(2.0)
