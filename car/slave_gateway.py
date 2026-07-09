#!/usr/bin/env python3
"""从车车际 TCP 网关：监听 6001，接收主车 RELAY，执行后回 ACK。

6000 留给从车本地 ROS（若有）；手机不直连从车。
"""

from __future__ import annotations

import json
import logging
import socket
from pathlib import Path

from protocol import build_ack, extract_framed_messages, parse_relay

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("slave_gateway")


class SlaveGateway:
    def __init__(self, config_path: str = "config_slave.json") -> None:
        config_file = Path(config_path)
        if not config_file.is_absolute():
            config_file = Path(__file__).parent / config_path
        if not config_file.exists():
            raise FileNotFoundError(f"config not found: {config_file}")
        with config_file.open("r", encoding="utf-8") as fp:
            cfg = json.load(fp)

        self.car_tcp_host = cfg.get("car_tcp_host", cfg.get("relay_host", "0.0.0.0"))
        self.car_tcp_port = int(cfg.get("car_tcp_port", cfg.get("relay_port", 6001)))
        self.local_ros_host = str(cfg.get("local_ros_host", "")).strip()
        self.local_ros_port = int(cfg.get("local_ros_port", 0))

    def _forward_to_local_ros(self, payload: str) -> None:
        if not self.local_ros_host or not self.local_ros_port:
            logger.warning(
                "local_ros not configured, skip execute: %s (set local_ros_host/port in config_slave.json)",
                payload,
            )
            return
        try:
            with socket.create_connection(
                (self.local_ros_host, self.local_ros_port),
                timeout=1.0,
            ) as sock:
                sock.sendall(payload.encode("utf-8"))
            logger.info(
                "forwarded to local ros %s:%s -> %s",
                self.local_ros_host, self.local_ros_port, payload,
            )
        except OSError as exc:
            logger.warning(
                "forward to local ros %s:%s failed: %s",
                self.local_ros_host, self.local_ros_port, exc,
            )

    def start(self) -> None:
        server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.bind((self.car_tcp_host, self.car_tcp_port))
        server.listen(5)
        logger.info("slave car-tcp listening on %s:%s", self.car_tcp_host, self.car_tcp_port)
        while True:
            conn, addr = server.accept()
            logger.info("master connected from %s", addr)
            self._handle_master(conn)

    def _handle_master(self, conn: socket.socket) -> None:
        buffer = ""
        try:
            while True:
                chunk = conn.recv(4096)
                if not chunk:
                    break
                buffer += chunk.decode("utf-8", errors="ignore")
                frames, buffer = extract_framed_messages(buffer)
                for frame in frames:
                    relay = parse_relay(frame)
                    if relay is None:
                        logger.debug("ignore frame: %s", frame)
                        continue
                    seq, payload = relay
                    logger.info("relay seq=%s payload=%s", seq, payload)
                    self._forward_to_local_ros(payload)
                    conn.sendall(build_ack(seq).encode("utf-8"))
        except OSError as exc:
            logger.warning("master connection error: %s", exc)
        finally:
            conn.close()
            logger.info("master disconnected")


def main() -> None:
    SlaveGateway().start()


if __name__ == "__main__":
    main()
