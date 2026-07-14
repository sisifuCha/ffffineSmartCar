"""FastAPI 入口：本地 Web 建图控制台。"""

from __future__ import annotations

import asyncio
import logging
from contextlib import asynccontextmanager
from datetime import datetime
from pathlib import Path
from typing import Any

import uvicorn
import yaml
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import FileResponse, Response
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

from .car_tcp import CarTcpClient
from .explorer import Explorer
from .sensor_client import SensorClient
from .slam_engine import SlamEngine
from .video_source import VideoSource
from .vision_detector import encode_jpeg
from .wall_follower import WallFollower

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("mapping_web")

ROOT = Path(__file__).resolve().parent.parent
FRONTEND = ROOT / "frontend"
MAPS_DIR = ROOT / "maps"
CONFIG_PATH = ROOT / "config.yaml"


def load_config() -> dict[str, Any]:
    with CONFIG_PATH.open("r", encoding="utf-8") as fp:
        return yaml.safe_load(fp)


cfg = load_config()
car_cfg = cfg["car"]
slam_cfg = cfg.get("slam", {})
explorer_cfg = cfg.get("explorer", {})
vision_cfg = cfg.get("vision", {})

slam = SlamEngine(
    resolution=float(slam_cfg.get("resolution", 0.05)),
    map_size_m=float(slam_cfg.get("map_size_m", 20.0)),
)
car = CarTcpClient(car_cfg["ip"], int(car_cfg["tcp_port"]))
ws_url = f"ws://{car_cfg['ip']}:{int(car_cfg['sensor_ws_port'])}"
sensor = SensorClient(ws_url, slam)
explorer = Explorer(
    slam,
    car,
    tolerance_m=float(explorer_cfg.get("goal_tolerance_m", 0.25)),
    max_linear=int(explorer_cfg.get("max_linear", 40)),
    step_timeout_sec=float(explorer_cfg.get("step_timeout_sec", 30)),
)

_ip = car_cfg["ip"]
_stream_templates = vision_cfg.get(
    "stream_urls",
    ["http://{ip}:6500/?action=stream", "http://{ip}:6500/stream"],
)
video_urls = [u.format(ip=_ip) for u in _stream_templates]
_discover = vision_cfg.get("discover_page")
discover_page = _discover.format(ip=_ip) if _discover else None
video = VideoSource(video_urls, discover_page=discover_page)
wall_follower = WallFollower(
    video,
    car,
    target_distance_px=float(vision_cfg.get("target_distance_px", 120)),
    forward_speed=int(vision_cfg.get("forward_speed", 28)),
    max_lateral=int(vision_cfg.get("max_lateral", 35)),
    control_hz=float(vision_cfg.get("control_hz", 10)),
    obstacle_stop_ratio=float(vision_cfg.get("obstacle_stop_ratio", 0.12)),
)

from .ws_hub import WsHub  # noqa: E402

hub = WsHub()


async def _push_task() -> None:
    await hub.push_loop(slam.get_snapshot, hz=5.0)


@asynccontextmanager
async def lifespan(app: FastAPI):
    video.start()
    sensor.start()
    push_task = asyncio.create_task(_push_task())
    logger.info("auto-started sensor ws %s and video capture", ws_url)
    yield
    push_task.cancel()
    wall_follower.stop()
    explorer.stop()
    sensor.stop()
    video.stop()


app = FastAPI(title="SmartCar Mapping Web", lifespan=lifespan)
MAPS_DIR.mkdir(parents=True, exist_ok=True)
app.mount("/static", StaticFiles(directory=str(FRONTEND)), name="static")


class VelocityBody(BaseModel):
    vx: int = 0
    vy: int = 0


class WallFollowBody(BaseModel):
    side: str = "left"
    target_distance_px: float | None = None


@app.get("/")
async def index() -> FileResponse:
    return FileResponse(FRONTEND / "index.html")


@app.get("/api/status")
async def status() -> dict:
    last = wall_follower.last_result
    hints: list[str] = []
    if not sensor.connected:
        hints.append(f"传感器 WS 未连上 ({ws_url})，车上运行 ./start_relay.sh 30")
    elif not sensor.has_scan:
        hints.append(
            "WS 已连但无雷达数据：车上用 ./start_relay_docker.sh 30（/scan 在 Docker 里时）"
        )
        if sensor.last_error:
            hints.append(sensor.last_error)
    if not video.connected:
        if video.last_error:
            hints.append(f"视频: {video.last_error}")
        else:
            hints.append("视频拉流中，请稍候或检查 vision.stream_urls")
    return {
        "sensor_connected": sensor.connected,
        "sensor_has_scan": sensor.has_scan,
        "sensor_error": sensor.last_error,
        "sensor_ws": ws_url,
        "video_connected": video.connected,
        "video_url": video.active_url,
        "video_error": video.last_error,
        "mapping": slam.is_mapping(),
        "exploring": explorer.running,
        "wall_following": wall_follower.running,
        "wall_side": wall_follower._side if wall_follower.running else None,
        "vision": {
            "wall_found": last.wall_found if last else False,
            "distance_px": last.distance_px if last else 0,
            "obstacle_ahead": last.obstacle_ahead if last else False,
        },
        "car_ip": car_cfg["ip"],
        "hints": hints,
    }


@app.post("/api/sensor/connect")
async def sensor_connect() -> dict:
    sensor.start()
    return {"ok": True}


@app.post("/api/mapping/start")
async def mapping_start() -> dict:
    slam.reset()
    slam.start()
    sensor.start()
    return {"ok": True}


@app.post("/api/mapping/stop")
async def mapping_stop() -> dict:
    slam.stop()
    wall_follower.stop()
    explorer.stop()
    car.stop()
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    path = MAPS_DIR / f"map_{ts}.pgm"
    slam.save_pgm(str(path))
    return {"ok": True, "path": str(path)}


@app.post("/api/explore/start")
async def explore_start() -> dict:
    wall_follower.stop()
    if not slam.is_mapping():
        slam.reset()
        slam.start()
    sensor.start()
    explorer.start()
    return {"ok": True}


@app.post("/api/explore/stop")
async def explore_stop() -> dict:
    explorer.stop()
    car.stop()
    return {"ok": True}


@app.post("/api/wallfollow/start")
async def wallfollow_start(body: WallFollowBody) -> dict:
    explorer.stop()
    side = "right" if body.side.lower() == "right" else "left"
    if body.target_distance_px is not None:
        wall_follower.target_distance_px = float(body.target_distance_px)
    if not slam.is_mapping():
        slam.start()
    sensor.start()
    video.start()
    wall_follower.start(side=side)
    return {"ok": True, "side": side, "target_distance_px": wall_follower.target_distance_px}


@app.post("/api/wallfollow/stop")
async def wallfollow_stop() -> dict:
    wall_follower.stop()
    car.stop()
    return {"ok": True}


@app.post("/api/control/velocity")
async def control_velocity(body: VelocityBody) -> dict:
    ok = car.send_velocity(body.vx, body.vy)
    return {"ok": ok}


@app.post("/api/control/stop")
async def control_stop() -> dict:
    wall_follower.stop()
    explorer.stop()
    ok = car.stop()
    return {"ok": ok}


@app.get("/api/video")
async def video_proxy() -> Response:
    import httpx

    url = (
        f"http://{car_cfg['ip']}:{int(car_cfg['video_port'])}"
        f"{car_cfg.get('video_path', '/index2')}"
    )
    try:
        async with httpx.AsyncClient(timeout=10.0, follow_redirects=True) as client:
            resp = await client.get(url)
            if resp.status_code >= 400:
                logger.warning("video proxy %s -> HTTP %s", url, resp.status_code)
                return Response(
                    content=f"car video HTTP {resp.status_code}: {url}".encode(),
                    status_code=502,
                )
            return Response(
                content=resp.content,
                media_type=resp.headers.get("content-type", "text/html"),
            )
    except Exception as exc:
        logger.warning("video proxy failed: %s", exc)
        return Response(content=b"video unavailable", status_code=502)


@app.get("/api/vision/debug.jpg")
async def vision_debug() -> Response:
    video.start()
    result = wall_follower.last_result
    if result and result.debug_bgr is not None:
        return Response(content=encode_jpeg(result.debug_bgr), media_type="image/jpeg")
    frame = video.get_frame()
    if frame is None:
        return Response(content=b"", status_code=503)
    return Response(content=encode_jpeg(frame), media_type="image/jpeg")


@app.websocket("/ws/map")
async def ws_map(ws: WebSocket) -> None:
    await ws.accept()
    await hub.register(ws)
    try:
        await ws.send_json(slam.get_snapshot())
        while True:
            await ws.receive_text()
    except WebSocketDisconnect:
        pass
    finally:
        await hub.unregister(ws)


def main() -> None:
    host = cfg.get("server", {}).get("host", "127.0.0.1")
    port = int(cfg.get("server", {}).get("port", 8080))
    logger.info("open http://%s:%s", host, port)
    uvicorn.run(app, host=host, port=port, log_level="info")


if __name__ == "__main__":
    main()
