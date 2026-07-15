"""Yahboom $...# TCP 协议：构建前后左右 / 速度指令。"""

from __future__ import annotations


# cmd 0x15 方向键（与手机 App 一致）
DIR_STOP = 0
DIR_FORWARD = 1
DIR_BACKWARD = 2
DIR_LEFT = 3
DIR_RIGHT = 4
DIR_SPIN_LEFT = 5
DIR_SPIN_RIGHT = 6

ACTION_TO_DIR = {
    "STOP": DIR_STOP,
    "FORWARD": DIR_FORWARD,
    "FORWARD_SLOW": DIR_FORWARD,
    "BACKWARD": DIR_BACKWARD,
    "LEFT": DIR_LEFT,
    "RIGHT": DIR_RIGHT,
    "TURN_LEFT": DIR_SPIN_LEFT,
    "TURN_RIGHT": DIR_SPIN_RIGHT,
    "STRAFE_LEFT": DIR_LEFT,
    "STRAFE_RIGHT": DIR_RIGHT,
}


def _checksum(parts: list[int]) -> int:
    return sum(parts) % 256


def build_direction_packet(car_type: int, direction: int) -> str:
    """构建 $011504011B# 形式的方向指令。"""
    cmd = 0x15
    length = 4  # 2 + 2 * 1 payload byte
    parts = [car_type & 0xFF, cmd, length, direction & 0xFF]
    body = "".join(f"{b:02X}" for b in parts)
    return f"${body}{_checksum(parts):02X}#"


def build_motion_packet(car_type: int, speed_x: float, speed_y: float) -> str:
    """
    cmd 0x10 摇杆速度控制。
    speed_x = num_y/100, speed_y = -num_x/100
    speed_x > 0 前进，< 0 后退
    speed_y > 0 右移/右转，< 0 左移/左转
    """
    cmd = 0x10
    num_y = max(-128, min(127, int(round(speed_x * 100))))
    num_x = max(-128, min(127, int(round(-speed_y * 100))))
    ny = num_y & 0xFF
    nx = num_x & 0xFF
    length = 6  # 2 + 2*2 payload bytes
    parts = [car_type & 0xFF, cmd, length, nx, ny]
    body = "".join(f"{b:02X}" for b in parts)
    return f"${body}{_checksum(parts):02X}#"


def build_enter_remote(car_type: int) -> str:
    """进入遥控模式（func=1）。"""
    cmd = 0x0F
    length = 4
    parts = [car_type & 0xFF, cmd, length, 0x01]
    body = "".join(f"{b:02X}" for b in parts)
    return f"${body}{_checksum(parts):02X}#"


def action_to_packet(
    car_type: int,
    action: str,
    speed_x: float = 0.0,
    speed_y: float = 0.0,
    forward_speed: float = 0.15,
    slow_speed: float = 0.06,
    turn_speed: float = 0.4,
) -> str:
    """
    根据动作构建控制帧（稳定版映射）。
    前进/后退/慢速 → cmd 0x10 速度指令
    原地转弯       → cmd 0x15 DIR_SPIN（TURN_LEFT/RIGHT）
    侧墙边走边偏   → cmd 0x15 DIR_LEFT/RIGHT（LEFT/RIGHT）
    停止           → cmd 0x15 STOP
    """
    if action == "STOP":
        return build_direction_packet(car_type, DIR_STOP)

    # 原地旋转避障（control_step 里用 turn_step_duration ≈ 500ms）
    if action == "TURN_LEFT":
        return build_direction_packet(car_type, DIR_SPIN_LEFT)
    if action == "TURN_RIGHT":
        return build_direction_packet(car_type, DIR_SPIN_RIGHT)

    if action == "FORWARD":
        return build_motion_packet(car_type, forward_speed, 0.0)
    if action == "FORWARD_SLOW":
        return build_motion_packet(car_type, slow_speed, 0.0)
    if action == "BACKWARD":
        return build_motion_packet(car_type, -forward_speed, 0.0)

    # 边走边偏（侧墙微调）
    if action == "LEFT":
        return build_direction_packet(car_type, DIR_LEFT)
    if action == "RIGHT":
        return build_direction_packet(car_type, DIR_RIGHT)

    if abs(speed_x) + abs(speed_y) > 0.001:
        return build_motion_packet(car_type, speed_x, speed_y)
    return build_direction_packet(car_type, DIR_STOP)
