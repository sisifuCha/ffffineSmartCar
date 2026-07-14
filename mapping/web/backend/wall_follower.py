"""视觉沿墙/栏杆行驶：保持与边缘的目标距离。"""

from __future__ import annotations

import asyncio
import logging
import time
from typing import Literal, Optional

from .car_tcp import CarTcpClient
from .video_source import VideoSource
from .vision_detector import VisionResult, analyze_wall

logger = logging.getLogger("wall_follower")

Side = Literal["left", "right"]


class WallFollower:
    def __init__(
        self,
        video: VideoSource,
        car: CarTcpClient,
        target_distance_px: float = 120.0,
        forward_speed: int = 30,
        max_lateral: int = 35,
        control_hz: float = 10.0,
        obstacle_stop_ratio: float = 0.12,
    ) -> None:
        self.video = video
        self.car = car
        self.target_distance_px = target_distance_px
        self.forward_speed = forward_speed
        self.max_lateral = max_lateral
        self.control_hz = control_hz
        self.obstacle_stop_ratio = obstacle_stop_ratio
        self._running = False
        self._task: Optional[asyncio.Task] = None
        self._side: Side = "left"
        self.last_result: Optional[VisionResult] = None

    @property
    def running(self) -> bool:
        return self._running

    def start(self, side: Side = "left") -> None:
        if self._running and self._task and not self._task.done():
            return
        self._side = side
        self._running = True
        self.video.start()
        self._task = asyncio.create_task(self._loop())

    def stop(self) -> None:
        self._running = False
        self.car.stop()
        if self._task:
            self._task.cancel()

    async def _loop(self) -> None:
        interval = 1.0 / max(self.control_hz, 1.0)
        try:
            while self._running:
                frame = self.video.get_frame()
                if frame is None:
                    await asyncio.sleep(interval)
                    continue

                result = analyze_wall(frame, side=self._side)
                self.last_result = result

                if result.obstacle_ahead and result.obstacle_ratio > self.obstacle_stop_ratio:
                    logger.info("obstacle ahead, stop")
                    self.car.stop()
                    await asyncio.sleep(0.5)
                    continue

                vx, vy = self._compute_velocity(result)
                self.car.send_velocity(vx, vy)
                await asyncio.sleep(interval)
        except asyncio.CancelledError:
            pass
        finally:
            self.car.stop()
            self._running = False

    def _compute_velocity(self, result: VisionResult) -> tuple[int, int]:
        """cmd10: vx 横向, vy 前进（与 App 摇杆一致）。"""
        vy = self.forward_speed

        if not result.wall_found:
            # 没看到墙：慢速前进 + 向墙一侧微转
            lateral = self.max_lateral // 2
            vx = lateral if self._side == "left" else -lateral
            return vx, vy // 2

        error = result.distance_px - self.target_distance_px
        # 距离太近 → 往远离墙方向横移；太远 → 往墙方向靠近
        gain = 0.25
        if self._side == "left":
            vx = int(-error * gain)
        else:
            vx = int(error * gain)

        vx = max(-self.max_lateral, min(self.max_lateral, vx))
        return vx, vy
