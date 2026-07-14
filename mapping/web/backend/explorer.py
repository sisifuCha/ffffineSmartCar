"""自动 frontier 探索建图。"""

from __future__ import annotations

import asyncio
import logging
import time
from typing import Optional

from .car_tcp import CarTcpClient
from .motion import goal_to_velocity
from .slam_engine import SlamEngine

logger = logging.getLogger("explorer")


class Explorer:
    def __init__(
        self,
        slam: SlamEngine,
        car: CarTcpClient,
        tolerance_m: float = 0.25,
        max_linear: int = 40,
        step_timeout_sec: float = 30.0,
    ) -> None:
        self.slam = slam
        self.car = car
        self.tolerance_m = tolerance_m
        self.max_linear = max_linear
        self.step_timeout_sec = step_timeout_sec
        self._running = False
        self._task: Optional[asyncio.Task] = None

    @property
    def running(self) -> bool:
        return self._running

    def start(self) -> None:
        if self._task and not self._task.done():
            return
        self.slam.start()
        self._running = True
        self._task = asyncio.create_task(self._loop())

    def stop(self) -> None:
        self._running = False
        self.car.stop()
        if self._task:
            self._task.cancel()

    async def _loop(self) -> None:
        try:
            while self._running:
                goal = self.slam.find_frontier_goal()
                if goal is None:
                    logger.info("no frontier, explore done")
                    self._running = False
                    self.car.stop()
                    break
                gx, gy = goal
                logger.info("frontier goal (%.2f, %.2f)", gx, gy)
                deadline = time.time() + self.step_timeout_sec
                while self._running and time.time() < deadline:
                    snap = self.slam.get_snapshot()
                    p = snap["pose"]
                    dist = ((p["x"] - gx) ** 2 + (p["y"] - gy) ** 2) ** 0.5
                    if dist < self.tolerance_m:
                        self.car.stop()
                        break
                    vx, vy = goal_to_velocity(
                        p["x"], p["y"], p["theta"], gx, gy, self.max_linear
                    )
                    self.car.send_velocity(vx, vy)
                    await asyncio.sleep(0.15)
                self.car.stop()
                await asyncio.sleep(0.3)
        except asyncio.CancelledError:
            self.car.stop()
        finally:
            self._running = False
