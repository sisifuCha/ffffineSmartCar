"""目标点 → cmd10 速度。"""

from __future__ import annotations

import math
from typing import Tuple


def goal_to_velocity(
    px: float,
    py: float,
    theta: float,
    gx: float,
    gy: float,
    max_linear: int = 40,
    max_angular_deg: float = 30,
) -> Tuple[int, int]:
    dx = gx - px
    dy = gy - py
    dist = math.hypot(dx, dy)
    if dist < 1e-6:
        return 0, 0

    target_angle = math.atan2(dy, dx)
    angle_err = _normalize_angle(target_angle - theta)

    # 先转向，再前进（简化：vx=前进分量在车身坐标系）
    cos_t = math.cos(theta)
    sin_t = math.sin(theta)
    forward = dx * cos_t + dy * sin_t
    lateral = -dx * sin_t + dy * cos_t

    vx = int(max(-max_linear, min(max_linear, forward * max_linear / max(dist, 0.5))))
    vy = int(max(-max_linear, min(max_linear, lateral * max_linear / max(dist, 0.5))))

    # 角度偏差大时减少前进
    if abs(math.degrees(angle_err)) > max_angular_deg:
        vx = int(vx * 0.3)
        vy = int(vy * 0.3)

    return vx, vy


def _normalize_angle(a: float) -> float:
    while a > math.pi:
        a -= 2 * math.pi
    while a < -math.pi:
        a += 2 * math.pi
    return a
