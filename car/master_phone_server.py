#!/usr/bin/env python3
"""主车手机 TCP 服务（6000）：车上尚无 ROS 时用这个先跑起来。

端口分工：
  - 6000  本脚本监听，收手机 App 指令
  - 6001  编排器出站连接从车，做车际 RELAY（本脚本不监听 6001）
"""

from __future__ import annotations

import logging
import socket
import threading

from command_executor import CommandExecutor
from orchestrator import MasterOrchestrator
from protocol import extract_framed_messages

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("master_phone_server")


class MasterPhoneServer:
    def __init__(self, host: str = "0.0.0.0", port: int = 6000) -> None:
        self.host = host
        self.port = port
        executor = CommandExecutor()
        self.orchestrator = MasterOrchestrator.from_config()
        self._on_execute = executor.execute
        self._running = True

    def start(self) -> None:
        server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.bind((self.host, self.port))
        server.listen(1)
        logger.info("master phone server listening on %s:%s", self.host, self.port)
        while self._running:
            conn, addr = server.accept()
            logger.info("phone connected from %s", addr)
            threading.Thread(target=self._handle_phone, args=(conn, addr), daemon=True).start()

    def _handle_phone(self, conn: socket.socket, addr) -> None:
        def phone_send(data: str) -> None:
            conn.sendall(data.encode("utf-8"))

        self.orchestrator.bind_phone(phone_send)
        buffer = ""
        try:
            while self._running:
                chunk = conn.recv(4096)
                if not chunk:
                    break
                buffer += chunk.decode("utf-8", errors="ignore")
                frames, buffer = extract_framed_messages(buffer)
                for frame in frames:
                    if not self.orchestrator.handle_frame(frame, self._on_execute):
                        logger.debug("unhandled frame: %s", frame)
        except OSError as exc:
            logger.warning("phone connection error from %s: %s", addr, exc)
        finally:
            conn.close()
            self.orchestrator.unbind_phone()
            logger.info("phone disconnected from %s", addr)


def main() -> None:
    MasterPhoneServer().start()


if __name__ == "__main__":
    main()
