#!/usr/bin/env python3
"""PC 端雷达数据接收器 — 在笔记本 192.168.27.39 上运行。

用法（Windows/Linux 笔记本）:
  pip install websockets
  python pc_lidar_receiver.py

默认监听 0.0.0.0:6603，接收小车推送的 @SCAN/@ODOM 帧。
可选保存到 lidar_data/ 目录。
"""

from __future__ import annotations

import argparse
import asyncio
import json
import logging
import time
from pathlib import Path
from typing import Any

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
logger = logging.getLogger("pc_receiver")

SCAN_PREFIX = "@SCAN"
ODOM_PREFIX = "@ODOM"


def parse_frame(msg: str) -> tuple[str, dict] | None:
    msg = msg.strip()
    for prefix in (SCAN_PREFIX, ODOM_PREFIX):
        if msg.startswith(prefix) and msg.endswith("#"):
            try:
                return prefix, json.loads(msg[len(prefix):-1])
            except json.JSONDecodeError:
                return None
    return None


async def handler(ws: Any, save_dir: Path | None, stats: dict) -> None:
    peer = ws.remote_address
    logger.info("car connected from %s", peer)
    try:
        async for raw in ws:
            parsed = parse_frame(raw)
            if not parsed:
                continue
            kind, data = parsed
            stats["frames"] += 1
            stats["last_t"] = time.time()
            if kind == SCAN_PREFIX:
                stats["scans"] += 1
                n = len(data.get("ranges", []))
                if stats["scans"] == 1:
                    logger.info("first scan received (%s points)", n)
                elif stats["scans"] % 50 == 0:
                    logger.info("received %s scans (latest %s points)", stats["scans"], n)
                if save_dir:
                    ts = int(data.get("t", time.time()) * 1000)
                    path = save_dir / f"scan_{ts}.json"
                    path.write_text(json.dumps(data), encoding="utf-8")
            elif kind == ODOM_PREFIX:
                stats["odoms"] += 1
    except Exception as exc:
        logger.warning("connection closed: %s", exc)
    finally:
        logger.info("car disconnected from %s", peer)


async def main_async(host: str, port: int, save: bool) -> None:
    try:
        import websockets
    except ImportError as exc:
        raise SystemExit("pip install websockets") from exc

    save_dir = Path("lidar_data") if save else None
    if save_dir:
        save_dir.mkdir(exist_ok=True)
        logger.info("saving scans to %s/", save_dir.resolve())

    stats = {"frames": 0, "scans": 0, "odoms": 0, "last_t": 0.0}

    async def on_connect(ws: Any) -> None:
        await handler(ws, save_dir, stats)

    async with websockets.serve(on_connect, host, port, ping_interval=20):
        logger.info("listening on ws://%s:%s — waiting for car upload", host, port)
        logger.info("ensure Jetson runs: ./collect_lidar.sh")
        await asyncio.Future()


def main() -> None:
    parser = argparse.ArgumentParser(description="PC lidar receiver")
    parser.add_argument("--host", default="0.0.0.0", help="listen address")
    parser.add_argument("--port", type=int, default=6603, help="listen port")
    parser.add_argument("--save", action="store_true", help="save each scan to lidar_data/")
    args = parser.parse_args()
    try:
        asyncio.run(main_async(args.host, args.port, args.save))
    except KeyboardInterrupt:
        logger.info("stopped")


if __name__ == "__main__":
    main()
