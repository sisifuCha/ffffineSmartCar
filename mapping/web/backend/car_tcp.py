"""TCP :6000 发送控制指令到小车 ROS。"""

from __future__ import annotations

import logging
import socket
import threading
from typing import Optional

from .car_protocol import encode_cmd10, encode_stop

logger = logging.getLogger("car_tcp")


class CarTcpClient:
    def __init__(self, host: str, port: int) -> None:
        self.host = host
        self.port = port
        self._lock = threading.Lock()

    def send(self, payload: str) -> bool:
        try:
            with self._lock:
                with socket.create_connection((self.host, self.port), timeout=2.0) as sock:
                    sock.sendall(payload.encode("utf-8"))
            logger.debug("sent %s", payload)
            return True
        except OSError as exc:
            logger.warning("tcp send failed: %s", exc)
            return False

    def send_velocity(self, vx: int, vy: int) -> bool:
        return self.send(encode_cmd10(vx, vy))

    def stop(self) -> bool:
        return self.send(encode_stop())
