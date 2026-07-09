#!/usr/bin/env python3
"""主车 ROS 执行完一条 $...# 后，用本脚本转发给从车 6001。

用法（在 smartcar 目录下）:
  python3 relay_cmd.py '$011504011B#'

或在 ROS 里执行完指令后 shell 调用:
  python3 /home/jetson/smartcar/relay_cmd.py "$payload"
"""

from __future__ import annotations

import logging
import sys
from pathlib import Path

from orchestrator import MasterOrchestrator

CONFIG = Path(__file__).parent / "config_master.json"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)


def main() -> None:
    if len(sys.argv) < 2:
        print("usage: python3 relay_cmd.py '$011504011B#'", file=sys.stderr)
        sys.exit(1)
    payload = sys.argv[1].strip()
    orch = MasterOrchestrator.from_config(str(CONFIG))
    print(f"relay to {orch.slave_ip}:{orch.car_tcp_port} -> {payload}")
    ok = orch.relay_command_sync(payload)
    if ok:
        print("OK: slave received command")
        sys.exit(0)
    print("FAIL: slave not reached (check slave_ip, slave_gateway, port 6001)", file=sys.stderr)
    sys.exit(1)


if __name__ == "__main__":
    main()
