"""融合雷达 + OpenCV 视觉的沿墙建图决策。

核心原则：
- 雷达是前方安全的第一判据，视觉只做辅助
- 大空地（没侧墙、前方通畅）→ 直行探索，不原地转圈
- 只有雷达确认前方有障碍才转弯避障
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
    ) -> None:
        self.follow_side = follow_side
        self.target_dist_m = target_dist_m
        self.target_wall_px = target_wall_px
        self.front_stop_m = front_stop_m
        self.front_slow_m = front_slow_m
        self.step = 0
        # 连续转弯计数：避免连续转太多圈
        self._consecutive_turns = 0

    def _lidar_sectors(self, scan: dict[str, Any]) -> dict[str, Optional[float]]:
        ranges = scan.get("ranges", [])
        if not ranges:
            return {"front": None, "side": None, "front_left": None, "front_right": None}
        angle_min = float(scan.get("angle_min", 0))
        inc = float(scan.get("angle_increment", 0))
        rmax = float(scan.get("range_max", 8))

        def sector(lo_deg: float, hi_deg: float) -> Optional[float]:
            lo, hi = math.radians(min(lo_deg, hi_deg)), math.radians(max(lo_deg, hi_deg))
            best = None
            ang = angle_min
            for r in ranges:
                if 0.05 < r < rmax and lo <= ang <= hi:
                    best = r if best is None else min(best, r)
                ang += inc
            return best

        if self.follow_side == "right":
            side = sector(-110, -70)
            front_side = sector(-70, -35)   # 右前方
            other_side = sector(35, 70)      # 左前方（仅参考）
        else:
            side = sector(70, 110)
            front_side = sector(35, 70)      # 左前方
            other_side = sector(-70, -35)    # 右前方（仅参考）
        front = sector(-35, 35)
        return {"front": front, "side": side, "front_side": front_side, "other_side": other_side}

    def decide(
        self,
        scan: Optional[dict[str, Any]],
        vision: Optional[dict[str, Any]],
    ) -> Dict[str, Any]:
        vis = vision or {}
        sectors = self._lidar_sectors(scan) if scan else {
            "front": None, "side": None, "front_side": None, "other_side": None
        }
        front_m = sectors["front"]
        side_m = sectors["side"]
        front_side_m = sectors["front_side"]
        follow = float(vis.get("follow_wall", 0))
        front_v = float(vis.get("front_wall", 0))
        corner = vis.get("corner_hint", "none")
        wall_px = vis.get("wall_dist_px")
        side_cn = "右" if self.follow_side == "right" else "左"
        # 前方避障：原地旋转（短时间 500ms）
        turn_away = "TURN_LEFT" if self.follow_side == "right" else "TURN_RIGHT"
        # 掉头：原地旋转（长时间 1300ms，转约 180°）
        u_turn = "U_TURN_LEFT" if self.follow_side == "right" else "U_TURN_RIGHT"
        # 侧墙微调：轻微弧线偏转（比避障转弯幅度小）
        steer_away = "STEER_LEFT" if self.follow_side == "right" else "STEER_RIGHT"

        # ============ 1) 前方硬安全门（雷达） ============
        # 雷达是前方避障的唯一权威判据
        if front_m is not None and front_m < self.front_stop_m:
            self.step += 1
            self._consecutive_turns += 1
            # 走廊末端：前方有墙 + 侧方也近 → 掉头
            if side_m is not None and side_m < self.target_dist_m * 1.5:
                return self._plan(u_turn, f"第{self.step}步：走廊末端（前 {front_m:.2f}m 侧 {side_m:.2f}m）— 掉头")
            # 普通前方障碍：短转避障
            return self._plan(turn_away, f"第{self.step}步：雷达前方 {front_m:.2f}m — 转弯避障")

        # ============ 2) 视觉前方墙角（需雷达辅助确认） ============
        # 只有雷达也显示前方偏近时，才信视觉的前方墙判断
        # 防止 OpenCV 边缘检测在大空地误判
        if (front_v > 0.35 or corner == "concave") and front_m is not None and front_m < self.front_slow_m:
            self.step += 1
            self._consecutive_turns += 1
            if side_m is not None and side_m < self.target_dist_m * 1.5:
                return self._plan(u_turn, f"第{self.step}步：视觉+雷达走廊末端 — 掉头")
            return self._plan(turn_away, f"第{self.step}步：视觉+雷达前方 — 转弯避障")

        # 前方安全通过，重置连续转弯计数
        self._consecutive_turns = 0

        # ============ 3) 侧向太近 → 轻微弧线偏转 ============
        # STEER 用 motion packet（前进+小幅侧向），比 TURN 温和
        if side_m is not None and side_m < self.target_dist_m * 0.5:
            return self._plan(steer_away, f"雷达：离{side_cn}墙 {side_m:.2f}m 太近 — 轻微偏转")

        if wall_px is not None and wall_px < self.target_wall_px * 0.5:
            return self._plan(steer_away, f"视觉：离{side_cn}墙太近 — 轻微偏转")

        # ============ 4) 前方偏近 → 慢速前进 ============
        if front_m is not None and front_m < self.front_slow_m:
            return self._plan("FORWARD_SLOW", f"前方 {front_m:.2f}m — 慢速沿{side_cn}墙前进")

        # ============ 5) 有侧墙信号 → 沿墙前进 ============
        side_following = (
            follow >= 0.12
            or (side_m is not None and 0.2 < side_m < 2.0)
            or (front_side_m is not None and front_side_m < 1.5)
        )
        if side_following:
            return self._plan("FORWARD", f"沿{side_cn}墙前进，保持约 {self.target_dist_m}m")

        # ============ 6) 大空地：前方通畅 → 直行探索 ============
        # 楼里也有墙，但如果侧方雷达没检测到（太远/角度问题），就先直行
        # 等雷达扫到墙再开始沿墙
        return self._plan("FORWARD", "前方通畅 — 直行探索")

    def _plan(self, action: str, guide_cn: str) -> Dict[str, Any]:
        return {
            "action": action,
            "guide_cn": guide_cn,
            "follow_side": self.follow_side,
            "move_forward": action in ("FORWARD", "FORWARD_SLOW", "STEER_LEFT", "STEER_RIGHT", "LEFT", "RIGHT"),
        }
