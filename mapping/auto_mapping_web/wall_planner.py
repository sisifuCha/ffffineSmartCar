"""融合雷达 + OpenCV 视觉的沿墙建图决策。

核心原则（稳定版）：
- 雷达是前方安全的第一判据，视觉只做辅助
- 前方障碍 → TURN（原地旋转，短 500ms）
- 侧墙太近 → LEFT/RIGHT（边走边偏，不原地转圈）
- 大空地 → 直行，不转圈
"""

from __future__ import annotations

import math
from typing import Any, Dict, Optional


class WallPlanner:
    """输出离散动作，映射到 car_protocol 前后左右。"""

    def __init__(
        self,
        follow_side: str = "right",
        target_dist_m: float = 0.45,
        target_wall_px: float = 120.0,
        front_stop_m: float = 0.80,
        front_slow_m: float = 1.30,
        # 支架自击常见在 ~0.08~0.15m，低于此一律当无效
        ignore_below_m: float = 0.18,
    ) -> None:
        self.follow_side = follow_side
        self.target_dist_m = target_dist_m
        self.target_wall_px = target_wall_px
        self.front_stop_m = front_stop_m
        self.front_slow_m = front_slow_m
        self.ignore_below_m = ignore_below_m
        self.step = 0
        self._consecutive_turns = 0
        self._logged_scan_meta = False

    @staticmethod
    def _min_dist(*vals: Optional[float]) -> Optional[float]:
        valid = [v for v in vals if v is not None]
        return min(valid) if valid else None

    def lidar_sectors(self, scan: Optional[dict[str, Any]]) -> dict[str, Optional[float]]:
        """正前/侧向/前侧/对侧扇区最短距离（米）。

        - 忽略 ignore_below_m 以内的点（支架自击，常见恒定 ~0.11m）
        - 「正前」只取车头方向窄扇区，不用过宽的左右前（避免走廊侧墙触发硬停）
        """
        empty = {
            "front": None, "side": None, "front_side": None,
            "other_side": None, "front_core": None,
        }
        if not scan:
            return empty
        ranges = scan.get("ranges", [])
        if not ranges:
            return empty
        angle_min = float(scan.get("angle_min", 0))
        inc = float(scan.get("angle_increment", 0))
        rmax = float(scan.get("range_max", 8))
        r_lo = self.ignore_below_m
        self._last_rmax = rmax

        if not self._logged_scan_meta:
            self._logged_scan_meta = True
            n = len(ranges)
            amax = angle_min + inc * max(0, n - 1)
            print(
                f"[wall_planner] scan meta: n={n} angle_min={math.degrees(angle_min):.1f}° "
                f"angle_max={math.degrees(amax):.1f}° ignore_below={r_lo}m"
            )

        def norm(a: float) -> float:
            return math.atan2(math.sin(a), math.cos(a))

        def sector(lo_deg: float, hi_deg: float) -> Optional[float]:
            """返回扇区最短有效距离。

            空地时雷达常回 inf / ≥range_max，旧逻辑全丢掉 → 显示成「—」。
            若扇区内只有「通畅」回波，则返回 rmax，表示前方开阔。
            """
            lo, hi = math.radians(min(lo_deg, hi_deg)), math.radians(max(lo_deg, hi_deg))
            best = None
            saw_clear = False
            saw_beam = False
            for i, r in enumerate(ranges):
                try:
                    rv = float(r)
                except (TypeError, ValueError):
                    continue
                ang = norm(angle_min + i * inc)
                if not (lo <= ang <= hi):
                    continue
                saw_beam = True
                if rv != rv or rv <= 0:
                    continue
                # 过近 = 支架噪点，丢掉
                if rv <= r_lo:
                    continue
                # 过远 / inf = 该方向通畅
                if rv >= rmax or rv == float("inf"):
                    saw_clear = True
                    continue
                best = rv if best is None else min(best, rv)
            if best is not None:
                return best
            if saw_clear:
                return rmax  # 开阔，不是 0，也不是无数据
            if saw_beam:
                return None  # 有波束但全是噪点/无效
            return None

        if self.follow_side == "right":
            side = sector(-110, -70)
            front_side = sector(-70, -35)   # 右前，仅沿墙参考
            other_side = sector(35, 70)     # 左前，仅参考
        else:
            side = sector(70, 110)
            front_side = sector(35, 70)
            other_side = sector(-70, -35)

        # 硬停用「车头」：略宽中心 + 贴近中心的左右条带（不含走廊侧墙角度）
        front_core = sector(-30, 30)
        front_l = sector(25, 50)
        front_r = sector(-50, -25)
        front = self._min_dist(front_core, front_l, front_r)

        return {
            "front": front,
            "side": side,
            "front_side": front_side,
            "other_side": other_side,
            "front_core": front_core,
        }

    def decide(
        self,
        scan: Optional[dict[str, Any]],
        vision: Optional[dict[str, Any]],
        *,
        count_step: bool = True,
    ) -> Dict[str, Any]:
        vis = vision or {}
        sectors = self.lidar_sectors(scan)
        front_m = sectors["front"]
        side_m = sectors["side"]
        front_side_m = sectors["front_side"]
        follow = float(vis.get("follow_wall", 0))
        front_v = float(vis.get("front_wall", 0))
        corner = vis.get("corner_hint", "none")
        wall_px = vis.get("wall_dist_px")
        side_cn = "右" if self.follow_side == "right" else "左"
        turn_away = "TURN_LEFT" if self.follow_side == "right" else "TURN_RIGHT"
        steer_away = "LEFT" if self.follow_side == "right" else "RIGHT"

        front_clearance = front_m

        def finish(action: str, guide_cn: str) -> Dict[str, Any]:
            return self._plan(action, guide_cn, sectors, front_clearance)

        # ============ 1) 前方硬安全门（雷达） ============
        if front_clearance is not None and front_clearance < self.front_stop_m:
            if count_step:
                self.step += 1
                self._consecutive_turns += 1
            step_s = f"第{self.step}步：" if count_step else "预览："
            return finish(turn_away, f"{step_s}雷达前方 {front_clearance:.2f}m — 原地转弯避障")

        # ============ 2) 视觉前方墙角（需雷达辅助确认） ============
        if (front_v > 0.35 or corner == "concave") and front_clearance is not None and front_clearance < self.front_slow_m:
            if count_step:
                self.step += 1
                self._consecutive_turns += 1
            step_s = f"第{self.step}步：" if count_step else "预览："
            return finish(turn_away, f"{step_s}视觉+雷达前方 — 原地转弯避障")

        if count_step:
            self._consecutive_turns = 0

        # ============ 3) 侧向太近 → 边走边转向远离 ============
        if side_m is not None and side_m < self.target_dist_m * 0.5:
            prefix = "预览：" if not count_step else ""
            return finish(steer_away, f"{prefix}雷达：离{side_cn}墙 {side_m:.2f}m 太近 — 边走边偏")

        if wall_px is not None and wall_px < self.target_wall_px * 0.5:
            prefix = "预览：" if not count_step else ""
            return finish(steer_away, f"{prefix}视觉：离{side_cn}墙太近 — 边走边偏")

        # ============ 4) 前方偏近 → 慢速前进 ============
        if front_clearance is not None and front_clearance < self.front_slow_m:
            prefix = "预览：" if not count_step else ""
            return finish("FORWARD_SLOW", f"{prefix}前方 {front_clearance:.2f}m — 慢速沿{side_cn}墙前进")

        # ============ 5) 有侧墙信号 → 沿墙前进 ============
        side_following = (
            follow >= 0.12
            or (side_m is not None and 0.2 < side_m < 2.0)
            or (front_side_m is not None and front_side_m < 1.5)
        )
        if side_following:
            prefix = "预览：" if not count_step else ""
            return finish("FORWARD", f"{prefix}沿{side_cn}墙前进，保持约 {self.target_dist_m}m")

        # ============ 6) 大空地 → 直行探索 ============
        prefix = "预览：" if not count_step else ""
        return finish("FORWARD", f"{prefix}前方通畅 — 直行探索")

    def _plan(
        self,
        action: str,
        guide_cn: str,
        sectors: Optional[dict[str, Optional[float]]] = None,
        front_clearance: Optional[float] = None,
    ) -> Dict[str, Any]:
        sec = sectors or {
            "front": None, "side": None, "front_side": None,
            "other_side": None, "front_core": None,
        }

        def fmt(v: Optional[float]) -> Optional[float]:
            return None if v is None else round(float(v), 3)

        display_front = front_clearance if front_clearance is not None else sec.get("front")

        return {
            "action": action,
            "guide_cn": guide_cn,
            "follow_side": self.follow_side,
            "move_forward": action in ("FORWARD", "FORWARD_SLOW", "LEFT", "RIGHT"),
            "lidar": {
                "front_m": fmt(display_front),
                "front_core_m": fmt(sec.get("front_core")),
                "side_m": fmt(sec.get("side")),
                "front_side_m": fmt(sec.get("front_side")),
                "other_side_m": fmt(sec.get("other_side")),
                "range_max_m": float(getattr(self, "_last_rmax", 8.0)),
            },
            "thresholds": {
                "front_stop_m": self.front_stop_m,
                "front_slow_m": self.front_slow_m,
                "target_dist_m": self.target_dist_m,
                "ignore_below_m": self.ignore_below_m,
            },
        }
