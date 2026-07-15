"""TCP 客户端：向小车 app.py :6000 发送 $...# 控制帧。"""

from __future__ import annotations

import logging
import socket
import threading
import time
from typing import Optional

from car_protocol import action_to_packet, build_enter_remote, build_direction_packet, DIR_STOP

logger = logging.getLogger("car_client")


class CarClient:
    def __init__(self, host: str, port: int = 6000, car_type: int = 1) -> None:
        self.host = host
        self.port = port
        self.car_type = car_type
        self._sock: Optional[socket.socket] = None
        self._lock = threading.Lock()
        self._last_action = "STOP"
        self._initialized = False

    def connect(self) -> bool:
        try:
            sock = socket.create_connection((self.host, self.port), timeout=3.0)
            sock.settimeout(2.0)
            self._sock = sock
            self._send_raw(build_enter_remote(self.car_type))
            time.sleep(0.2)
            self._initialized = True
            logger.info("connected to car %s:%s", self.host, self.port)
            return True
        except OSError as exc:
            logger.warning("car connect failed: %s", exc)
            self._sock = None
            return False

    def _send_raw(self, packet: str) -> bool:
        if not self._sock:
            return False
        try:
            self._sock.sendall(packet.encode("utf-8"))
            return True
        except OSError as exc:
            logger.warning("send failed: %s", exc)
            self._sock = None
            return False

    def send_action(
        self,
        action: str,
        speed_x: float = 0.0,
        speed_y: float = 0.0,
        forward_speed: float = 0.15,
        slow_speed: float = 0.06,
        turn_speed: float = 0.4,
    ) -> bool:
        with self._lock:
            if not self._sock and not self.connect():
                return False
            pkt = action_to_packet(
                self.car_type, action, speed_x, speed_y,
                forward_speed=forward_speed,
                slow_speed=slow_speed,
                turn_speed=turn_speed,
            )
            ok = self._send_raw(pkt)
            if ok:
                self._last_action = action
            return ok

    def stop(self) -> None:
        with self._lock:
            if self._sock:
                self._send_raw(build_direction_packet(self.car_type, DIR_STOP))
            try:
                if self._sock:
                    self._sock.close()
            except OSError:
                pass
            self._sock = None

    @property
    def last_action(self) -> str:
        return self._last_action
