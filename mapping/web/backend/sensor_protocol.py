"""解析小车 WebSocket 传感帧 @SCAN / @ODOM。"""

from __future__ import annotations

import json
from dataclasses import dataclass
from typing import Any, Optional


@dataclass
class ScanFrame:
    ranges: list[float]
    angle_min: float
    angle_max: float
    angle_increment: float
    range_min: float
    range_max: float
    t: float


@dataclass
class OdomFrame:
    x: float
    y: float
    theta: float
    vx: float
    vy: float
    t: float


def parse_frames(buffer: str) -> tuple[list[Any], str]:
    frames: list[Any] = []
    while True:
        scan_idx = buffer.find("@SCAN")
        odom_idx = buffer.find("@ODOM")
        if scan_idx < 0 and odom_idx < 0:
            break
        if scan_idx < 0 or (odom_idx >= 0 and odom_idx < scan_idx):
            start = odom_idx
            prefix = "@ODOM"
        else:
            start = scan_idx
            prefix = "@SCAN"
        end = buffer.find("#", start)
        if end < 0:
            break
        raw = buffer[start + len(prefix) : end]
        try:
            data = json.loads(raw)
            if prefix == "@SCAN":
                frames.append(
                    ScanFrame(
                        ranges=list(data["ranges"]),
                        angle_min=float(data["angle_min"]),
                        angle_max=float(data["angle_max"]),
                        angle_increment=float(data["angle_increment"]),
                        range_min=float(data.get("range_min", 0.05)),
                        range_max=float(data.get("range_max", 12.0)),
                        t=float(data.get("t", 0)),
                    )
                )
            else:
                frames.append(
                    OdomFrame(
                        x=float(data["x"]),
                        y=float(data["y"]),
                        theta=float(data["theta"]),
                        vx=float(data.get("vx", 0)),
                        vy=float(data.get("vy", 0)),
                        t=float(data.get("t", 0)),
                    )
                )
        except (json.JSONDecodeError, KeyError, TypeError):
            pass
        buffer = buffer[end + 1 :]
    return frames, buffer
