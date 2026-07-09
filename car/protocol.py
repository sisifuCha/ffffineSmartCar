"""双车编排层协议：RELAY / ACK / @STATUS / @CONFIG"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from typing import Optional

RELAY_PREFIX = "RELAY|"
ACK_PREFIX = "ACK|"
STATUS_PREFIX = "@STATUS"
CONFIG_PREFIX = "@CONFIG"
CONTROL_START = "$"
CONTROL_END = "#"

RELAY_PATTERN = re.compile(r"^RELAY\|(\d+)\|(\$[^#]+#)\|$")
ACK_PATTERN = re.compile(r"^ACK\|(\d+)\|(\w+)\|$")


@dataclass
class StatusPayload:
    mode: str = "master_only"
    slave_online: bool = False
    last_ack_ms: int = -1
    seq: int = 0

    def to_json(self) -> str:
        return json.dumps({
            "mode": self.mode,
            "slaveOnline": self.slave_online,
            "lastAckMs": self.last_ack_ms,
            "seq": self.seq,
        }, separators=(",", ":"))

    @staticmethod
    def from_json(raw: str) -> "StatusPayload":
        data = json.loads(raw)
        return StatusPayload(
            mode=data.get("mode", "master_only"),
            slave_online=bool(data.get("slaveOnline", False)),
            last_ack_ms=int(data.get("lastAckMs", -1)),
            seq=int(data.get("seq", 0)),
        )


@dataclass
class ConfigPayload:
    dual_mode: bool = False
    slave_ip: str = ""
    slave_port: int = 6001

    def to_json(self) -> str:
        return json.dumps({
            "dualMode": self.dual_mode,
            "slaveIp": self.slave_ip,
            "slavePort": self.slave_port,
        }, separators=(",", ":"))

    @staticmethod
    def from_json(raw: str) -> "ConfigPayload":
        data = json.loads(raw)
        return ConfigPayload(
            dual_mode=bool(data.get("dualMode", False)),
            slave_ip=str(data.get("slaveIp", "")),
            slave_port=int(data.get("slavePort", 6001)),
        )


def build_relay(seq: int, control_payload: str) -> str:
    return f"{RELAY_PREFIX}{seq}|{control_payload}|"


def build_ack(seq: int, status: str = "OK") -> str:
    return f"{ACK_PREFIX}{seq}|{status}|"


def build_status(status: StatusPayload) -> str:
    return f"{STATUS_PREFIX}{status.to_json()}#"


def build_config(config: ConfigPayload) -> str:
    return f"{CONFIG_PREFIX}{config.to_json()}#"


def parse_relay(message: str) -> Optional[tuple[int, str]]:
    match = RELAY_PATTERN.match(message.strip())
    if not match:
        return None
    return int(match.group(1)), match.group(2)


def parse_ack(message: str) -> Optional[tuple[int, str]]:
    match = ACK_PATTERN.match(message.strip())
    if not match:
        return None
    return int(match.group(1)), match.group(2)


def extract_framed_messages(buffer: str) -> tuple[list[str], str]:
    """从流式缓冲区拆出完整帧（以 # 结尾的 @ 帧或 $ 帧，以及 RELAY/ACK 行）。"""
    frames: list[str] = []
    lines = buffer.split("\n")
    remainder = ""
    if buffer and not buffer.endswith("\n"):
        remainder = lines.pop() if lines else buffer
        if not lines and remainder and not remainder.endswith("#") and not remainder.endswith("|"):
            return frames, remainder

    pending = remainder
    if pending:
        lines.append(pending)

    carry = ""
    for line in lines:
        text = (carry + line).strip()
        carry = ""
        if not text:
            continue
        if text.startswith(RELAY_PREFIX) or text.startswith(ACK_PREFIX):
            if text.endswith("|"):
                frames.append(text)
            else:
                carry = text
            continue
        if text.startswith(STATUS_PREFIX) or text.startswith(CONFIG_PREFIX) or text.startswith(CONTROL_START):
            if text.endswith("#"):
                frames.append(text)
            else:
                carry = text
            continue
        carry = text

    return frames, carry


def parse_status(message: str) -> Optional[StatusPayload]:
    text = message.strip()
    if not text.startswith(STATUS_PREFIX) or not text.endswith("#"):
        return None
    raw = text[len(STATUS_PREFIX):-1]
    try:
        return StatusPayload.from_json(raw)
    except json.JSONDecodeError:
        return None


def parse_config(message: str) -> Optional[ConfigPayload]:
    text = message.strip()
    if not text.startswith(CONFIG_PREFIX) or not text.endswith("#"):
        return None
    raw = text[len(CONFIG_PREFIX):-1]
    try:
        return ConfigPayload.from_json(raw)
    except json.JSONDecodeError:
        return None


def is_control_command(message: str) -> bool:
    text = message.strip()
    return text.startswith(CONTROL_START) and text.endswith(CONTROL_END)
