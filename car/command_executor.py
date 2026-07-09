"""解析并执行 $...# 控制指令（可对接 ROS 节点）。"""

from __future__ import annotations

import logging
import re
from typing import Callable, Optional

logger = logging.getLogger(__name__)

CONTROL_PATTERN = re.compile(r"^\$([0-9A-Fa-f]+)([0-9A-Fa-f]{2})#?$")

ExecuteHook = Callable[[str, str, str], None]


class CommandExecutor:
    """将 $...# 指令解析后交给回调执行。"""

    def __init__(self, on_execute: Optional[ExecuteHook] = None) -> None:
        self._on_execute = on_execute or self._default_execute

    def execute(self, payload: str) -> bool:
        text = payload.strip()
        if not text.startswith("$") or not text.endswith("#"):
            logger.warning("invalid control payload: %s", text)
            return False
        body = text[1:-1]
        if len(body) < 6:
            logger.warning("control payload too short: %s", text)
            return False
        vehicle_type = body[0:2]
        cmd = body[2:4]
        data_len = body[4:6]
        info = body[6:-2] if len(body) > 8 else ""
        checksum = body[-2:] if len(body) >= 8 else ""
        logger.info(
            "execute cmd=%s len=%s info=%s checksum=%s",
            cmd, data_len, info, checksum,
        )
        self._on_execute(vehicle_type, cmd, info)
        return True

    @staticmethod
    def _default_execute(vehicle_type: str, cmd: str, info: str) -> None:
        logger.info(
            "[CommandExecutor] vehicle=%s cmd=%s info=%s (hook ROS here)",
            vehicle_type, cmd, info,
        )
