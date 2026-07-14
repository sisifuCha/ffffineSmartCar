"""占用栅格地图渲染（PC 端）。

优先显示车端 gmapping 发来的 @MAP（完整占用栅格），
没有 @MAP 时回退到本地 @SCAN 栅格叠加（不做 ICP）。
"""

from __future__ import annotations

import base64
import math
from typing import Any, Optional


class OccupancySlam:
    def __init__(
        self,
        resolution: float = 0.05,
        map_size_m: float = 24.0,
        hit_logodd: float = 0.9,
        miss_logodd: float = -0.4,
    ) -> None:
        self.resolution = resolution
        self.size = int(map_size_m / resolution)
        self.origin = self.size // 2
        # 本地栅格（回退用）
        self.grid = [[0.0] * self.size for _ in range(self.size)]
        self.pose = {"x": 0.0, "y": 0.0, "theta": 0.0}
        self._hit_logodd = hit_logodd
        self._miss_logodd = miss_logodd
        self.has_odom = False
        self.has_pose = False
        self.scan_count = 0

        # 远程地图（车端 gmapping）
        self.remote_map: Optional[dict[str, Any]] = None
        self.remote_map_count = 0

    def update_remote_map(self, data: dict[str, Any]) -> None:
        """接收车端 gmapping 的 @MAP（OccupancyGrid，可能 zlib 压缩）。"""
        self.remote_map = data
        self.remote_map_count += 1
        if self.remote_map_count <= 3:
            import logging
            logging.getLogger("auto_mapping_web").info(
                "@MAP #%d keys=%s: %dx%d res=%.3f origin=(%.1f,%.1f) data_len=%d",
                self.remote_map_count,
                list(data.keys()),
                data.get("width", 0), data.get("height", 0),
                data.get("resolution", 0),
                data.get("origin_x", 0), data.get("origin_y", 0),
                len(data.get("data", "")),
            )

    def update_odom(self, odom: dict[str, Any]) -> None:
        """里程计位姿（odom 坐标系）。

        如果已有 SLAM 校正的 @POSE（map 坐标系），不再用 odom 覆盖，
        否则坐标系不一致会导致红点跑到错误位置。
        """
        if self.has_pose:
            return
        x = float(odom.get("x", 0))
        y = float(odom.get("y", 0))
        theta = float(odom.get("theta", 0))
        if not self.has_odom:
            self.has_odom = True
        self.pose["x"] = x
        self.pose["y"] = y
        self.pose["theta"] = theta

    def update_pose(self, pose: dict[str, Any]) -> None:
        """接收车端 SLAM 校正后的 @POSE（map 坐标系）。"""
        self.pose["x"] = float(pose.get("x", 0))
        self.pose["y"] = float(pose.get("y", 0))
        self.pose["theta"] = float(pose.get("theta", 0))
        self.has_pose = True

    def update_scan(self, scan: dict[str, Any]) -> None:
        """本地栅格回退：仅在没有 @MAP 时才叠加 @SCAN。"""
        if self.remote_map is not None:
            # 有远程地图，不做本地建图
            self.scan_count += 1
            return

        self.scan_count += 1
        px = self.pose["x"]
        py = self.pose["y"]
        th = self.pose["theta"]
        ranges = scan.get("ranges", [])
        angle_min = float(scan.get("angle_min", 0))
        angle_inc = float(scan.get("angle_increment", 0))
        rmin = float(scan.get("range_min", 0.05))
        rmax = float(scan.get("range_max", 8.0))

        for i, r in enumerate(ranges):
            try:
                dist = float(r)
            except (TypeError, ValueError):
                continue
            if dist != dist or dist <= rmin or dist >= rmax:
                continue
            ang = angle_min + i * angle_inc
            wx = px + dist * math.cos(th + ang)
            wy = py + dist * math.sin(th + ang)
            self._ray(px, py, wx, wy)

    def _ray(self, x0: float, y0: float, x1: float, y1: float) -> None:
        sx, sy = self._w2g(x0, y0)
        gx, gy = self._w2g(x1, y1)
        steps = max(abs(gx - sx), abs(gy - sy), 1)
        for s in range(steps):
            t = s / steps
            ix = int(sx + (gx - sx) * t)
            iy = int(sy + (gy - sy) * t)
            if 0 <= ix < self.size and 0 <= iy < self.size:
                self.grid[iy][ix] += self._miss_logodd
                if self.grid[iy][ix] < -3.0:
                    self.grid[iy][ix] = -3.0
        if 0 <= gx < self.size and 0 <= gy < self.size:
            self.grid[gy][gx] += self._hit_logodd
            if self.grid[gy][gx] > 3.0:
                self.grid[gy][gx] = 3.0

    def _w2g(self, x: float, y: float) -> tuple[int, int]:
        return int(self.origin + x / self.resolution), int(self.origin - y / self.resolution)

    def to_png_bytes(self) -> bytes:
        import io
        from PIL import Image

        if self.remote_map is not None:
            return self._render_remote_map()
        return self._render_local_grid()

    def _render_remote_map(self) -> bytes:
        """渲染车端 gmapping 的 OccupancyGrid。"""
        import io
        import zlib
        from PIL import Image

        rm = self.remote_map
        w = int(rm.get("width", 0))
        h = int(rm.get("height", 0))
        if w == 0 or h == 0:
            return self._render_local_grid()

        raw_b64 = rm.get("data", "")
        try:
            raw = base64.b64decode(raw_b64)
        except Exception:
            raw = raw_b64.encode("utf-8", errors="replace") if isinstance(raw_b64, str) else raw_b64

        # 尝试 zlib 解压（车端可能压缩了）
        if len(raw) < w * h:
            try:
                raw = zlib.decompress(raw)
            except Exception:
                pass  # 不是 zlib，直接用原始数据

        if len(raw) < w * h:
            # 数据不完整，跳过这帧
            return self._render_local_grid()

        res = float(rm.get("resolution", rm.get("res", 0.05)))
        # 兼容多种 origin 字段格式
        ox = float(rm.get("origin_x", rm.get("ox", 0)))
        oy = float(rm.get("origin_y", rm.get("oy", 0)))
        # 如果 origin 是列表格式 [x, y, theta]
        origin_list = rm.get("origin")
        if isinstance(origin_list, (list, tuple)) and len(origin_list) >= 2:
            ox = float(origin_list[0])
            oy = float(origin_list[1])

        # 诊断日志：前 5 次打印坐标变换细节
        if self.remote_map_count <= 5:
            import logging
            rx_m = self.pose["x"]
            ry_m = self.pose["y"]
            rpx_diag = int((rx_m - ox) / res)
            rpy_diag = h - int((ry_m - oy) / res)
            logging.getLogger("auto_mapping_web").info(
                "render_map #%d: pose=(%.2f,%.2f,%.2f) origin=(%.2f,%.2f) res=%.3f → px=(%d,%d) [w=%d,h=%d,has_pose=%s]",
                self.remote_map_count, rx_m, ry_m, self.pose["theta"],
                ox, oy, res, rpx_diag, rpy_diag, w, h, self.has_pose,
            )

        img = Image.new("RGB", (w, h), (90, 90, 90))
        px = img.load()
        # ROS OccupancyGrid: data[0] = 左下角，y 向上递增
        # 图片: pixel(0,0) = 左上角，y 向下递增
        # 需要翻转 y 轴：图片第 y 行 ← data 第 (h-1-y) 行
        for y in range(h):
            src_row = h - 1 - y
            for x in range(w):
                v = raw[src_row * w + x]
                if v < 0:
                    pass  # 未知，保持灰
                elif v > 50:
                    intensity = max(0, 80 - v // 2)
                    px[x, y] = (intensity, intensity, intensity)
                else:
                    px[x, y] = (230, 230, 230)

        # 画机器人位置（map 坐标系 → 像素）
        # OccupancyGrid 原点在左下角，x 向右，y 向上
        # pose 的 x, y 是 map 坐标系下的米
        rx_m = self.pose["x"]
        ry_m = self.pose["y"]
        # 像素坐标：origin 在左下角
        rpx = int((rx_m - ox) / res)
        rpy = h - int((ry_m - oy) / res)  # y 翻转
        if 0 <= rpx < w and 0 <= rpy < h:
            for dx in (-2, -1, 0, 1, 2):
                for dy in (-2, -1, 0, 1, 2):
                    nx, ny = rpx + dx, rpy + dy
                    if 0 <= nx < w and 0 <= ny < h:
                        px[nx, ny] = (255, 60, 60)
            for step in range(1, 15):
                hx = int(rpx + step * math.cos(self.pose["theta"]))
                hy = int(rpy - step * math.sin(self.pose["theta"]))
                if 0 <= hx < w and 0 <= hy < h:
                    px[hx, hy] = (80, 220, 80)

        buf = io.BytesIO()
        img.save(buf, format="PNG")
        return buf.getvalue()

    def _render_local_grid(self) -> bytes:
        """渲染本地栅格（回退模式）。"""
        import io
        from PIL import Image

        img = Image.new("RGB", (self.size, self.size), (90, 90, 90))
        px = img.load()
        for y in range(self.size):
            row = self.grid[y]
            for x in range(self.size):
                logodd = row[x]
                if logodd > 0.5:
                    intensity = max(0, int(80 - logodd * 30))
                    px[x, y] = (intensity, intensity, intensity)
                elif logodd < -0.3:
                    px[x, y] = (230, 230, 230)
        rx, ry = self._w2g(self.pose["x"], self.pose["y"])
        ix, iy = int(rx), int(ry)
        if 0 <= ix < self.size and 0 <= iy < self.size:
            for dx in (-2, -1, 0, 1, 2):
                for dy in (-2, -1, 0, 1, 2):
                    if 0 <= ix + dx < self.size and 0 <= iy + dy < self.size:
                        px[ix + dx, iy + dy] = (255, 60, 60)
            for step in range(1, 12):
                hx = int(ix + step * math.cos(self.pose["theta"]))
                hy = int(iy - step * math.sin(self.pose["theta"]))
                if 0 <= hx < self.size and 0 <= hy < self.size:
                    px[hx, hy] = (80, 220, 80)
        buf = io.BytesIO()
        img.save(buf, format="PNG")
        return buf.getvalue()

    def frontier_count(self) -> int:
        if self.remote_map is not None:
            rm = self.remote_map
            w = int(rm.get("width", 0))
            h = int(rm.get("height", 0))
            if w == 0 or h == 0:
                return 0
            try:
                raw = base64.b64decode(rm.get("data", ""))
                if len(raw) < w * h:
                    import zlib
                    raw = zlib.decompress(raw)
            except Exception:
                return 0
            if len(raw) < w * h:
                return 0
            n = 0
            for y in range(1, h - 1):
                for x in range(1, w - 1):
                    if raw[y * w + x] != 0:
                        continue
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        if raw[(y + dy) * w + (x + dx)] < 0:
                            n += 1
                            break
            return n
        # 本地栅格
        n = 0
        for y in range(1, self.size - 1):
            for x in range(1, self.size - 1):
                if -0.3 < self.grid[y][x] <= 0.5:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        if self.grid[y + dy][x + dx] < -0.5:
                            n += 1
                            break
        return n
