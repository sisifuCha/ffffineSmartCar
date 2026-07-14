"""$...# 控制帧编码（与 App CarEncode 一致）。"""

from __future__ import annotations


def _checksum_hex(body: str) -> str:
    total = 0
    for i in range(0, len(body), 2):
        total = (total + int(body[i : i + 2], 16)) % 256
    return f"{total:02X}"


def _base_encode(cmd: str, info: str = "") -> str:
    size = f"{len(info) + 2:02X}"
    body = "01" + cmd + size + info
    return f"${body}{_checksum_hex(body)}#"


def encode_cmd10(vx: int, vy: int) -> str:
    vx = max(-100, min(100, int(round(vx))))
    vy = max(-100, min(100, int(round(vy))))
    sx = vx + 256 if vx < 0 else vx
    sy = vy + 256 if vy < 0 else vy
    return _base_encode("10", f"{sx:02X}{sy:02X}")


def encode_cmd15(direction: int) -> str:
    d = max(0, min(7, int(direction)))
    return _base_encode("15", f"{d:02X}")


def encode_stop() -> str:
    return encode_cmd15(0)
