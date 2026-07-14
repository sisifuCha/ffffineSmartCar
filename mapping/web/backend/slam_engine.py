"""本地 2D 占用栅格建图（射线更新 + 里程计位姿）。"""

from __future__ import annotations

import math
import threading
from typing import Optional

import numpy as np

from .sensor_protocol import OdomFrame, ScanFrame

# 0=未知 1=空闲 2=障碍
UNKNOWN = 0
FREE = 1
OCCUPIED = 2


class SlamEngine:
    def __init__(self, resolution: float = 0.05, map_size_m: float = 20.0) -> None:
        self.resolution = resolution
        self.map_size_m = map_size_m
        self.grid_size = int(map_size_m / resolution)
        self.origin = (-map_size_m / 2, -map_size_m / 2)
        self.grid = np.zeros((self.grid_size, self.grid_size), dtype=np.uint8)
        self.pose = {"x": 0.0, "y": 0.0, "theta": 0.0}
        self._lock = threading.Lock()
        self._mapping = False
        self._has_odom = False

    def start(self) -> None:
        with self._lock:
            self._mapping = True

    def stop(self) -> None:
        with self._lock:
            self._mapping = False

    def is_mapping(self) -> bool:
        with self._lock:
            return self._mapping

    def reset(self) -> None:
        with self._lock:
            self.grid.fill(UNKNOWN)
            self.pose = {"x": 0.0, "y": 0.0, "theta": 0.0}
            self._has_odom = False

    def ingest_odom(self, odom: OdomFrame) -> None:
        with self._lock:
            if not self._mapping:
                return
            self.pose["x"] = odom.x
            self.pose["y"] = odom.y
            self.pose["theta"] = odom.theta
            self._has_odom = True

    def ingest_scan(self, scan: ScanFrame) -> None:
        with self._lock:
            if not self._mapping:
                return
            self._raycast_update(scan)

    def _world_to_grid(self, wx: float, wy: float) -> tuple[int, int]:
        gx = int((wx - self.origin[0]) / self.resolution)
        gy = int((wy - self.origin[1]) / self.resolution)
        return gx, gy

    def _raycast_update(self, scan: ScanFrame) -> None:
        px = self.pose["x"]
        py = self.pose["y"]
        theta = self.pose["theta"]
        gx0, gy0 = self._world_to_grid(px, py)
        if not self._in_bounds(gx0, gy0):
            return

        angle = scan.angle_min
        for r in scan.ranges:
            if r < scan.range_min or r > scan.range_max or math.isnan(r) or math.isinf(r):
                angle += scan.angle_increment
                continue
            beam = theta + angle
            ex = px + r * math.cos(beam)
            ey = py + r * math.sin(beam)
            gx1, gy1 = self._world_to_grid(ex, ey)
            self._bresenham_free(gx0, gy0, gx1, gy1)
            if self._in_bounds(gx1, gy1):
                self.grid[gy1, gx1] = OCCUPIED
            angle += scan.angle_increment

    def _in_bounds(self, gx: int, gy: int) -> bool:
        return 0 <= gx < self.grid_size and 0 <= gy < self.grid_size

    def _bresenham_free(self, x0: int, y0: int, x1: int, y1: int) -> None:
        dx = abs(x1 - x0)
        dy = abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx - dy
        x, y = x0, y0
        while True:
            if self._in_bounds(x, y) and self.grid[y, x] == UNKNOWN:
                self.grid[y, x] = FREE
            if x == x1 and y == y1:
                break
            e2 = 2 * err
            if e2 > -dy:
                err -= dy
                x += sx
            if e2 < dx:
                err += dx
                y += sy

    def get_snapshot(self) -> dict:
        with self._lock:
            return {
                "type": "map",
                "w": self.grid_size,
                "h": self.grid_size,
                "resolution": self.resolution,
                "origin": list(self.origin),
                "data": self.grid.flatten().tolist(),
                "pose": dict(self.pose),
                "mapping": self._mapping,
            }

    def save_pgm(self, path: str) -> None:
        with self._lock:
            # PGM: 0=黑障碍 255=白空闲 205=未知
            img = np.zeros((self.grid_size, self.grid_size), dtype=np.uint8)
            img[self.grid == UNKNOWN] = 205
            img[self.grid == FREE] = 254
            img[self.grid == OCCUPIED] = 0
            with open(path, "wb") as fp:
                fp.write(f"P5\n{self.grid_size} {self.grid_size}\n255\n".encode("ascii"))
                fp.write(img[::-1].tobytes())

    def find_frontier_goal(self) -> Optional[tuple[float, float]]:
        """找最近 frontier 格子中心（世界坐标）。"""
        with self._lock:
            px, py = self.pose["x"], self.pose["y"]
            best: Optional[tuple[float, float]] = None
            best_d = 1e9
            g = self.grid
            for gy in range(1, self.grid_size - 1):
                for gx in range(1, self.grid_size - 1):
                    if g[gy, gx] != FREE:
                        continue
                    if not self._is_frontier(gx, gy):
                        continue
                    wx = self.origin[0] + (gx + 0.5) * self.resolution
                    wy = self.origin[1] + (gy + 0.5) * self.resolution
                    d = (wx - px) ** 2 + (wy - py) ** 2
                    if d < best_d:
                        best_d = d
                        best = (wx, wy)
            return best

    def _is_frontier(self, gx: int, gy: int) -> bool:
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if dx == 0 and dy == 0:
                    continue
                nx, ny = gx + dx, gy + dy
                if 0 <= nx < self.grid_size and 0 <= ny < self.grid_size:
                    if self.grid[ny, nx] == UNKNOWN:
                        return True
        return False
