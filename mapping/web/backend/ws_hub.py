"""向前端 WebSocket 推送地图快照。"""

from __future__ import annotations

import asyncio
import json
import logging
from typing import Any, Set

logger = logging.getLogger("ws_hub")


class WsHub:
    def __init__(self) -> None:
        self.clients: Set[Any] = set()

    async def register(self, ws: Any) -> None:
        self.clients.add(ws)

    async def unregister(self, ws: Any) -> None:
        self.clients.discard(ws)

    async def broadcast(self, payload: dict) -> None:
        if not self.clients:
            return
        text = json.dumps(payload, separators=(",", ":"))
        dead: list[Any] = []
        for ws in self.clients:
            try:
                await ws.send(text)
            except Exception:
                dead.append(ws)
        for ws in dead:
            self.clients.discard(ws)

    async def push_loop(self, get_snapshot, hz: float = 5.0) -> None:
        interval = 1.0 / max(hz, 1.0)
        while True:
            await asyncio.sleep(interval)
            await self.broadcast(get_snapshot())
