"""ROS 桥接：在现有 6000 服务里调用编排器，不占用任何端口。"""

from __future__ import annotations

from typing import Callable

from orchestrator import MasterOrchestrator
from protocol import extract_framed_messages, is_control_command, parse_config

_orchestrator: MasterOrchestrator | None = None


def init(config_path: str = "config_master.json") -> MasterOrchestrator:
    global _orchestrator
    _orchestrator = MasterOrchestrator.from_config(config_path)
    return _orchestrator


def get() -> MasterOrchestrator:
    if _orchestrator is None:
        raise RuntimeError("ros_bridge not initialized, call init() first")
    return _orchestrator


def on_phone_connected(phone_send: Callable[[str], None]) -> None:
    get().bind_phone(phone_send)


def on_phone_disconnected() -> None:
    get().unbind_phone()


def process_phone_buffer(
    buffer: str,
    on_ros_execute: Callable[[str], None],
) -> tuple[str, list[str]]:
    """
    ROS 6000 收包后调用。

    - @CONFIG → 编排器处理
    - $...#   → 先 on_ros_execute（原有 ROS 逻辑），再 relay_command（6001 转发）
    返回 (剩余 buffer, 本次处理的帧列表)
    """
    orch = get()
    frames, remainder = extract_framed_messages(buffer)
    handled: list[str] = []
    for frame in frames:
        if parse_config(frame):
            orch.handle_phone_frame(frame)
            handled.append(frame)
            continue
        if is_control_command(frame):
            on_ros_execute(frame)
            orch.relay_command(frame)
            handled.append(frame)
            continue
    return remainder, handled
