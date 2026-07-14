"""从摄像头图像检测墙/栏杆边缘与前方障碍。"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Literal, Optional, Tuple

import cv2
import numpy as np

Side = Literal["left", "right"]


@dataclass
class VisionResult:
    wall_found: bool
    distance_px: float
    obstacle_ahead: bool
    obstacle_ratio: float
    debug_bgr: Optional[np.ndarray] = None


def analyze_wall(
    frame_bgr: np.ndarray,
    side: Side = "left",
    roi_y_ratio: float = 0.35,
) -> VisionResult:
    """在画面下半部分检测竖直边缘，估计与墙/栏杆的横向距离（像素）。"""
    h, w = frame_bgr.shape[:2]
    y0 = int(h * roi_y_ratio)
    roi = frame_bgr[y0:h, :]
    gray = cv2.cvtColor(roi, cv2.COLOR_BGR2GRAY)
    gray = cv2.GaussianBlur(gray, (5, 5), 0)
    edges = cv2.Canny(gray, 50, 150)

    # 前方障碍：画面中下区域边缘占比
    center = edges[h - y0 - int((h - y0) * 0.45) : h - y0, int(w * 0.3) : int(w * 0.7)]
    obstacle_ratio = float(np.count_nonzero(center)) / max(center.size, 1)
    obstacle_ahead = obstacle_ratio > 0.12

    col_score = edges.mean(axis=0)
    kernel = max(5, w // 40)
    col_score = np.convolve(col_score, np.ones(kernel) / kernel, mode="same")

    margin = int(w * 0.05)
    if side == "left":
        segment = col_score[margin : w // 2]
        offset = margin
    else:
        segment = col_score[w // 2 : w - margin]
        offset = w // 2

    if segment.size == 0 or segment.max() < 8:
        return VisionResult(
            wall_found=False,
            distance_px=0.0,
            obstacle_ahead=obstacle_ahead,
            obstacle_ratio=obstacle_ratio,
            debug_bgr=_draw_debug(frame_bgr, y0, side, None, obstacle_ahead),
        )

    peak_idx = int(np.argmax(segment))
    wall_col = offset + peak_idx
    if side == "left":
        distance_px = float(wall_col)
    else:
        distance_px = float(w - wall_col)

    debug = _draw_debug(frame_bgr, y0, side, wall_col, obstacle_ahead)
    return VisionResult(
        wall_found=True,
        distance_px=distance_px,
        obstacle_ahead=obstacle_ahead,
        obstacle_ratio=obstacle_ratio,
        debug_bgr=debug,
    )


def _draw_debug(
    frame: np.ndarray,
    y0: int,
    side: Side,
    wall_col: Optional[int],
    obstacle: bool,
) -> np.ndarray:
    out = frame.copy()
    h, w = out.shape[:2]
    cv2.line(out, (0, y0), (w, y0), (0, 255, 255), 1)
    if wall_col is not None:
        cv2.line(out, (wall_col, y0), (wall_col, h), (0, 255, 0), 2)
    label = f"wall:{side}"
    if obstacle:
        label += " STOP"
    cv2.putText(out, label, (10, 24), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 200, 255), 2)
    return out


def encode_jpeg(frame_bgr: np.ndarray, quality: int = 75) -> bytes:
    ok, buf = cv2.imencode(".jpg", frame_bgr, [int(cv2.IMWRITE_JPEG_QUALITY), quality])
    if not ok:
        return b""
    return buf.tobytes()
