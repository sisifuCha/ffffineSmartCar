"""主车编排：6000 由 ROS 收手机；6001 负责主车→从车 TCP 通信。"""

from __future__ import annotations

import json
import logging
import socket
import threading
import time
from pathlib import Path
from typing import Callable, Optional

from protocol import (
    StatusPayload,
    build_relay,
    build_status,
    is_control_command,
    parse_ack,
    parse_config,
)

logger = logging.getLogger("orchestrator")

PhoneSend = Callable[[str], None]


class MasterOrchestrator:
    """
    双车编排器。

  端口约定：
    - 6000：现有 ROS TCP 服务收手机（本类不监听 6000）
    - 6001：主车作为客户端连从车，发送 RELAY 帧（车际 TCP）
    """

    def __init__(
        self,
        slave_ip: str = "192.168.1.12",
        car_tcp_port: int = 6001,
        dual_mode: bool = True,
        ack_timeout_ms: int = 300,
        status_interval_sec: float = 1.0,
    ) -> None:
        self.slave_ip = slave_ip
        self.car_tcp_port = car_tcp_port
        self.dual_mode = dual_mode
        self.ack_timeout_ms = ack_timeout_ms
        self.status_interval_sec = status_interval_sec

        self.seq = 0
        self.slave_online = False
        self.last_ack_ms = -1
        self._phone_send: Optional[PhoneSend] = None
        self._phone_lock = threading.Lock()
        self._slave_lock = threading.Lock()
        self._running = True
        self._status_thread: Optional[threading.Thread] = None

    @classmethod
    def from_config(cls, config_path: str = "config_master.json") -> "MasterOrchestrator":
        config_file = Path(config_path)
        if not config_file.is_absolute():
            config_file = Path(__file__).parent / config_path
        if not config_file.exists():
            raise FileNotFoundError(f"config not found: {config_file}")
        with config_file.open("r", encoding="utf-8") as fp:
            cfg = json.load(fp)
        return cls(
            slave_ip=cfg.get("slave_ip", "192.168.1.12"),
            car_tcp_port=int(cfg.get("car_tcp_port", cfg.get("slave_port", 6001))),
            dual_mode=bool(cfg.get("dual_mode", True)),
            ack_timeout_ms=int(cfg.get("ack_timeout_ms", 300)),
            status_interval_sec=float(cfg.get("status_interval_sec", 1.0)),
        )

    def bind_phone(self, phone_send: PhoneSend) -> None:
        """ROS 在 6000 accept 手机后调用，用于回传 @STATUS。"""
        with self._phone_lock:
            self._phone_send = phone_send
        self._ensure_status_loop()

    def unbind_phone(self) -> None:
        with self._phone_lock:
            self._phone_send = None

    def handle_phone_frame(self, frame: str) -> bool:
        """处理手机发来的编排帧（@CONFIG）。控制指令 $...# 由 ROS 执行后调 relay_command。"""
        config = parse_config(frame)
        if not config:
            return False
        self.dual_mode = config.dual_mode
        if config.slave_ip:
            self.slave_ip = config.slave_ip
        if config.slave_port:
            self.car_tcp_port = config.slave_port
        logger.info(
            "config updated dual=%s slave=%s:%s",
            self.dual_mode, self.slave_ip, self.car_tcp_port,
        )
        self.push_status()
        return True

    def relay_command(self, payload: str) -> None:
        """
        ROS 在 6000 收到并执行完 $...# 后调用，经 6001 转发给从车。
        不重复执行，只负责车际 TCP。
        """
        if not is_control_command(payload):
            return
        if not self.dual_mode:
            self.push_status()
            return
        self._relay_to_slave(payload)

    def relay_command_sync(self, payload: str) -> bool:
        """CLI 测试用：同步转发，返回从车是否 ACK。"""
        if not is_control_command(payload):
            logger.warning("not a control command: %s", payload)
            return False
        if not self.dual_mode:
            logger.warning("dual_mode is off in config")
            return False
        self.seq += 1
        ok = self._relay_once(self.seq, payload)
        self.push_status()
        return ok

    def _relay_once(self, seq: int, payload: str) -> bool:
        relay_frame = build_relay(seq, payload)
        start = time.time()
        try:
            with self._slave_lock:
                with socket.create_connection(
                    (self.slave_ip, self.car_tcp_port),
                    timeout=self.ack_timeout_ms / 1000.0,
                ) as slave_sock:
                    slave_sock.sendall(relay_frame.encode("utf-8"))
                    slave_sock.settimeout(self.ack_timeout_ms / 1000.0)
                    data = slave_sock.recv(1024).decode("utf-8", errors="ignore")
            parsed = parse_ack(data.strip())
            if parsed and parsed[0] == seq and parsed[1] == "OK":
                self.slave_online = True
                self.last_ack_ms = int((time.time() - start) * 1000)
                logger.info(
                    "relay ok seq=%s to %s:%s ack_ms=%s",
                    seq, self.slave_ip, self.car_tcp_port, self.last_ack_ms,
                )
                return True
            logger.warning("relay bad ack seq=%s raw=%s", seq, data.strip())
        except OSError as exc:
            logger.warning(
                "car tcp relay failed seq=%s to %s:%s: %s",
                seq, self.slave_ip, self.car_tcp_port, exc,
            )
        self.slave_online = False
        self.last_ack_ms = -1
        return False

    def handle_frame(self, frame: str, on_execute: Callable[[str], None]) -> bool:
        """演示/测试用：CONFIG + 执行 + 转发一体。"""
        if self.handle_phone_frame(frame):
            return True
        if is_control_command(frame):
            on_execute(frame)
            self.relay_command(frame)
            return True
        return False

    def _relay_to_slave(self, payload: str) -> None:
        self.seq += 1
        current_seq = self.seq

        def worker() -> None:
            ok = self._relay_once(current_seq, payload)
            if not ok:
                logger.info("slave offline on :%s, degrade to master_only", self.car_tcp_port)
            self.push_status()

        threading.Thread(target=worker, daemon=True).start()

    def push_status(self) -> None:
        mode = "dual" if self.dual_mode and self.slave_online else "master_only"
        status = StatusPayload(
            mode=mode,
            slave_online=self.slave_online,
            last_ack_ms=self.last_ack_ms,
            seq=self.seq,
        )
        message = build_status(status)
        with self._phone_lock:
            if self._phone_send is None:
                return
            try:
                self._phone_send(message)
            except OSError as exc:
                logger.warning("push status failed: %s", exc)

    def _ensure_status_loop(self) -> None:
        if self._status_thread and self._status_thread.is_alive():
            return
        self._status_thread = threading.Thread(target=self._status_loop, daemon=True)
        self._status_thread.start()

    def _status_loop(self) -> None:
        while self._running:
            self.push_status()
            if self.dual_mode and not self.slave_online:
                self._probe_slave()
            time.sleep(self.status_interval_sec)

    def _probe_slave(self) -> None:
        try:
            with socket.create_connection(
                (self.slave_ip, self.car_tcp_port),
                timeout=0.5,
            ):
                logger.debug("slave car tcp port reachable")
        except OSError:
            pass

    def stop(self) -> None:
        self._running = False
