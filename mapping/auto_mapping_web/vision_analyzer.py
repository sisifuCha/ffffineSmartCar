"""纯 OpenCV 墙体识别（无需 YOLO，无需 GPU）。

用 Canny 边缘 + 垂直梯度 + 区域评分检测左/右/前方墙体。
只检测墙体特征（垂直边缘、纹理），不识别人/物体/动物。
"""

from __future__ import annotations

from typing import Any, Dict, Optional

import cv2
import numpy as np


class WallVisionAnalyzer:
    def __init__(
        self,
        yolo_weights: Optional[str] = None,  # 保留参数兼容，但不再使用
        conf_threshold: float = 0.35,
        min_wall_score: float = 0.12,
    ) -> None:
        self.min_wall_score = min_wall_score
        self._prev_side: Optional[float] = None

    def ensure_yolo(self) -> None:
        """兼容接口，不再加载 YOLO。"""
        pass

    @staticmethod
    def _region_wall_score(gray: np.ndarray) -> float:
        """计算一个区域的墙体置信度（0~1）。

        墙体特征：大量垂直边缘 + 均匀纹理 + 高梯度响应。
        """
        if gray.size == 0:
            return 0.0
        h, w = gray.shape[:2]
        blur = cv2.GaussianBlur(gray, (5, 5), 0)
        # Canny 边缘
        edges = cv2.Canny(blur, 30, 100)
        edge_density = float(np.mean(edges > 0))
        # 垂直梯度（墙体有强垂直边缘）
        sobel_x = cv2.Sobel(blur, cv2.CV_64F, 1, 0, ksize=3)
        vert_strength = float(np.mean(np.abs(sobel_x))) / 30.0
        # 水平梯度（地面/天花板分界线，辅助判断）
        sobel_y = cv2.Sobel(blur, cv2.CV_64F, 0, 1, ksize=3)
        horiz_strength = float(np.mean(np.abs(sobel_y))) / 30.0
        # 墙体通常：高垂直梯度 + 中等边缘密度 + 不太高水平梯度
        score = min(1.0, vert_strength * 0.5 + edge_density * 1.5 + horiz_strength * 0.2)
        return score

    @staticmethod
    def _detect_wall_lines(gray: np.ndarray) -> list:
        """用 Hough 变换检测墙体直线。"""
        blur = cv2.GaussianBlur(gray, (5, 5), 0)
        edges = cv2.Canny(blur, 50, 150)
        lines = cv2.HoughLinesP(edges, 1, np.pi / 180, threshold=40,
                                minLineLength=30, maxLineGap=15)
        result = []
        if lines is not None:
            for ln in lines:
                # HoughLinesP 返回 (N,1,4) 或 (N,4)，统一 flatten
                pts = ln.flatten()
                if len(pts) < 4:
                    continue
                x1, y1, x2, y2 = int(pts[0]), int(pts[1]), int(pts[2]), int(pts[3])
                angle = abs(np.arctan2(y2 - y1, x2 - x1) * 180 / np.pi)
                # 墙体线：接近垂直（70°~110°）或接近水平（-20°~20°）
                if 70 < angle < 110 or angle < 20 or angle > 160:
                    length = np.sqrt((x2 - x1) ** 2 + (y2 - y1) ** 2)
                    result.append({"x1": x1, "y1": y1, "x2": x2, "y2": y2,
                                   "angle": float(angle), "length": float(length)})
        return result

    def analyze(self, frame: np.ndarray, follow_side: str = "right") -> Dict[str, Any]:
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        h, w = gray.shape
        # 三等分：左、中、右
        t = w // 3
        left_roi = gray[:, :t]
        right_roi = gray[:, w - t:]
        front_roi = gray[:, t:w - t]

        left = self._region_wall_score(left_roi)
        right = self._region_wall_score(right_roi)
        front = self._region_wall_score(front_roi)

        # 检测前方墙体线（判断是否快撞墙）
        front_lines = self._detect_wall_lines(front_roi)
        # 前方有大量水平线 = 有墙挡路
        horiz_lines = [l for l in front_lines if l["angle"] < 20 or l["angle"] > 160]
        if len(horiz_lines) > 3:
            front = min(1.0, front + 0.2)

        side_score = right if follow_side == "right" else left

        # 角落检测
        corner = "none"
        if front > 0.45 and side_score > self.min_wall_score:
            corner = "concave"  # 前方和侧方都有墙 = 凹角
        elif self._prev_side is not None and self._prev_side - side_score > 0.18:
            corner = "convex"  # 侧墙突然消失 = 凸角
        self._prev_side = side_score

        # 估算侧墙像素距离
        wall_dist_px = self._estimate_wall_distance(frame, follow_side)

        # 检测到的墙体线（用于叠加显示）
        all_lines = []
        all_lines.extend(self._detect_wall_lines(left_roi))
        all_lines.extend(self._detect_wall_lines(front_roi))
        all_lines.extend(self._detect_wall_lines(right_roi))

        return {
            "valid": max(left, right, front) >= self.min_wall_score,
            "left_wall": round(left, 3),
            "right_wall": round(right, 3),
            "front_wall": round(front, 3),
            "follow_wall": round(side_score, 3),
            "wall_dist_px": wall_dist_px,
            "corner_hint": corner,
            "suggested_side": follow_side,
            "yolo_active": False,
            "boxes": [],
            "wall_lines": all_lines,
        }

    @staticmethod
    def _estimate_wall_distance(frame: np.ndarray, side: str) -> Optional[float]:
        """估算侧墙到画面边缘的像素距离。"""
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        h, w = gray.shape
        if side == "right":
            roi = gray[:, int(w * 0.5):]
            col_weights = np.mean(cv2.Canny(roi, 50, 150), axis=0)
        else:
            roi = gray[:, : int(w * 0.5)]
            col_weights = np.mean(cv2.Canny(roi, 50, 150), axis=0)
        if col_weights.size == 0 or col_weights.max() < 10:
            return None
        idx = int(np.argmax(col_weights))
        return float(idx if side == "left" else roi.shape[1] - idx)

    @staticmethod
    def draw_overlay(frame: np.ndarray, vis: Dict[str, Any], plan: Dict[str, Any]) -> np.ndarray:
        out = frame.copy()
        # 画检测到的墙体线（绿色）
        for ln in vis.get("wall_lines", []):
            cv2.line(out, (ln["x1"], ln["y1"]), (ln["x2"], ln["y2"]), (0, 200, 0), 2)
        # 画区域分割线（黄色虚线感）
        h, w = out.shape[:2]
        t = w // 3
        cv2.line(out, (t, 0), (t, h), (0, 255, 255), 1)
        cv2.line(out, (w - t, 0), (w - t, h), (0, 255, 255), 1)
        # 动作和提示
        action = plan.get("action", "STOP")
        msg = plan.get("guide_cn", "")
        cv2.putText(out, f"ACTION: {action}", (10, 24), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2)
        cv2.putText(out, msg[:60], (10, 52), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)
        # 墙体评分
        cv2.putText(out, f"L={vis.get('left_wall', 0):.2f} F={vis.get('front_wall', 0):.2f} R={vis.get('right_wall', 0):.2f}",
                    (10, 76), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 1)
        dist = vis.get("wall_dist_px")
        if dist is not None:
            cv2.putText(out, f"wall_dist={dist:.0f}px", (10, 100),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 1)
        return out
