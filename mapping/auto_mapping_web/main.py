#!/usr/bin/env python3
"""
Windows PC 自动建图 Web 服务

- 主动连接小车 sensor_relay ws://car:6602，接收 @SCAN/@ODOM
- 拉取小车视频 http://car:6500/video_feed
- YOLO 识别墙体 + 雷达 SLAM
- 下发 $...# 控制小车前后左右

用法:
  pip install -r requirements.txt
  copy config.yaml.example config.yaml   # 编辑 car.ip
  python main.py
  浏览器 http://127.0.0.1:8080
"""

from __future__ import annotations

import asyncio
import json
import logging
import threading
import time
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Any, Optional

import cv2
import numpy as np
import yaml
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import HTMLResponse, Response

from car_client import CarClient
from slam_map import OccupancySlam
from vision_analyzer import WallVisionAnalyzer
from wall_planner import WallPlanner

ROOT = Path(__file__).resolve().parent
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("auto_mapping_web")


class AppState:
    def __init__(self, cfg: dict[str, Any]) -> None:
        car = cfg.get("car", {})
        mapping = cfg.get("mapping", {})
        vision = cfg.get("vision", {})
        control = cfg.get("control", {})

        self.car_ip = car.get("ip", "192.168.27.221")
        self.video_port = int(car.get("video_http_port", 6500))
        self.car_type = int(car.get("car_type", 1))
        # PC 主动连小车 sensor_relay（默认 6602，与 mapping/car 一致）
        self.sensor_ws_port = int(car.get("sensor_ws_port", 6602))
        self.command_interval = int(control.get("command_interval_ms", 200)) / 1000.0
        # 步进控制：每个动作执行 step_duration_ms 后发 STOP，再停 step_pause_ms
        self.step_duration = int(control.get("step_duration_ms", 1200)) / 1000.0
        self.turn_step_duration = int(control.get("turn_step_duration_ms", 500)) / 1000.0
        self.step_pause = int(control.get("step_pause_ms", 600)) / 1000.0
        # 速度（0.0~1.0，映射到 -128~127）
        self.forward_speed = float(control.get("forward_speed", 0.15))
        self.slow_speed = float(control.get("slow_speed", 0.06))
        self.turn_speed = float(control.get("turn_speed", 0.4))

        video = cfg.get("video", {})
        self.video_fps = float(video.get("target_fps", 15))
        self.video_jpeg_quality = int(video.get("jpeg_quality", 70))
        self.yolo_every_n = max(1, int(video.get("yolo_every_n", 2)))
        self.buffer_drain = max(1, int(video.get("buffer_drain", 4)))
        self.ui_refresh_ms = int(cfg.get("server", {}).get("ui_refresh_ms", 150))

        self.slam = OccupancySlam(
            resolution=float(mapping.get("resolution", 0.05)),
            map_size_m=float(mapping.get("map_size_m", 24)),
        )
        self.vision = WallVisionAnalyzer(
            yolo_weights=vision.get("yolo_weights"),
            conf_threshold=float(vision.get("conf_threshold", 0.35)),
        ) if vision.get("enabled", True) else None
        self.planner = WallPlanner(
            follow_side=vision.get("follow_side", "right"),
            target_wall_px=float(vision.get("target_wall_px", 120)),
            target_dist_m=float(vision.get("target_dist_m", 0.45)),
            front_stop_m=float(control.get("front_stop_m", 0.80)),
            front_slow_m=float(control.get("front_slow_m", 1.30)),
        )
        self.car = CarClient(
            self.car_ip,
            int(car.get("control_tcp_port", 6000)),
            self.car_type,
        )

        self.latest_scan: Optional[dict] = None
        self.latest_odom: Optional[dict] = None
        self.latest_pose: Optional[dict] = None  # SLAM 校正后的 pose（@POSE）
        self.latest_vision: dict = {}
        self.latest_plan: dict = {"action": "STOP", "guide_cn": "等待启动"}
        self.latest_frame_jpeg: Optional[bytes] = None
        self.frame_seq = 0
        self.video_ok = False
        self.video_error = ""
        self.sensor_ok = False
        self.sensor_error = ""
        self._frame_interval = 1.0 / max(self.video_fps, 1.0)
        self.auto_running = bool(control.get("auto_start", False))
        self.scan_count = 0
        self._lock = threading.Lock()
        self._clients: set[WebSocket] = set()

    def parse_sensor_json(self, cmd: str, json_str: str) -> None:
        """直接从 cmd + json_str 解析（不再依赖 # 分隔符）。"""
        try:
            if cmd == "@SCAN":
                data = json.loads(json_str)
                with self._lock:
                    self.latest_scan = data
                    self.scan_count += 1
                    self.sensor_ok = True
                    self.sensor_error = ""
                    self.slam.update_scan(data)
            elif cmd == "@ODOM":
                data = json.loads(json_str)
                with self._lock:
                    self.latest_odom = data
                    if not self.latest_pose:
                        self.slam.update_odom(data)
            elif cmd == "@POSE":
                data = json.loads(json_str)
                with self._lock:
                    self.latest_pose = data
                    self.slam.update_pose(data)
            elif cmd == "@MAP":
                data = json.loads(json_str)
                with self._lock:
                    self.slam.update_remote_map(data)
                    self.sensor_ok = True
                    self.sensor_error = ""
        except Exception as exc:
            logger.warning("parse %s error: %s | json[:200]=%s", cmd, exc, json_str[:200])

    def parse_sensor(self, msg: str | bytes) -> None:
        if isinstance(msg, bytes):
            msg = msg.decode("utf-8", errors="replace")
        msg = msg.strip()
        if not msg:
            return
        try:
            if msg.startswith("@SCAN") and msg.endswith("#"):
                data = json.loads(msg[5:-1])
                with self._lock:
                    self.latest_scan = data
                    self.scan_count += 1
                    self.sensor_ok = True
                    self.sensor_error = ""
                    self.slam.update_scan(data)
            elif msg.startswith("@ODOM") and msg.endswith("#"):
                with self._lock:
                    self.latest_odom = json.loads(msg[5:-1])
                    if not self.latest_pose:
                        self.slam.update_odom(self.latest_odom)
            elif msg.startswith("@POSE") and msg.endswith("#"):
                with self._lock:
                    self.latest_pose = json.loads(msg[5:-1])
                    self.slam.update_pose(self.latest_pose)
            elif msg.startswith("@MAP") and msg.endswith("#"):
                with self._lock:
                    data = json.loads(msg[5:-1])
                    self.slam.update_remote_map(data)
                    self.sensor_ok = True
                    self.sensor_error = ""
            else:
                # 未知帧格式，打印前 200 字符帮助诊断
                logger.warning("unknown frame (first 200 chars): %s", msg[:200])
        except (json.JSONDecodeError, Exception) as exc:
            # 打印帧内容帮助调试
            logger.warning("parse error on %s...: %s | frame[:200]=%s", msg[:6], exc, msg[:200])

    def control_step(self) -> None:
        """走一步：决策 → 执行 step_duration → STOP → 等待 step_pause。
        未启动建图时只刷新决策预览（不发车端动作）。"""
        with self._lock:
            scan = self.latest_scan
            vis = self.latest_vision
            running = self.auto_running

        if not running:
            plan = self.planner.decide(scan, vis, count_step=False)
            plan["preview"] = True
            with self._lock:
                self.latest_plan = plan
            time.sleep(0.2)
            return

        plan = self.planner.decide(scan, vis, count_step=True)
        plan["preview"] = False
        action = plan["action"]
        with self._lock:
            self.latest_plan = plan
        try:
            self.car.send_action(
                action,
                forward_speed=self.forward_speed,
                slow_speed=self.slow_speed,
                turn_speed=self.turn_speed,
            )
        except Exception as exc:
            logger.warning("send action failed: %s", exc)
        if action.startswith("TURN"):
            duration = self.turn_step_duration
        else:
            duration = self.step_duration
        time.sleep(duration)
        if self.auto_running:
            try:
                self.car.send_action("STOP")
            except Exception:
                pass
        time.sleep(self.step_pause)

    def control_thread(self) -> None:
        """控制线程主循环，独立于 asyncio 事件循环。"""
        while True:
            try:
                self.control_step()
            except Exception as exc:
                logger.warning("control error: %s", exc)
                try:
                    self.car.send_action("STOP")
                except Exception:
                    pass
                time.sleep(1.0)

    def video_tick(self) -> None:
        frame_i = 0
        last_vis: dict = {}
        while True:
            url = f"http://{self.car_ip}:{self.video_port}/video_feed"
            cap = cv2.VideoCapture(url, cv2.CAP_FFMPEG)
            cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
            if not cap.isOpened():
                with self._lock:
                    self.video_ok = False
                    self.video_error = f"无法连接 {url}，请检查 PC config.yaml 中 car.ip 是否等于小车当前 IP"
                logger.warning("video open failed: %s (5s 后重试)", url)
                time.sleep(5)
                continue

            with self._lock:
                self.video_ok = True
                self.video_error = ""
            logger.info("video stream connected: %s (target %.0f fps)", url, self.video_fps)

            fail_streak = 0
            while True:
                t0 = time.perf_counter()
                try:
                    frame = self._read_latest_frame(cap)
                except Exception as exc:
                    logger.warning("video read error: %s", exc)
                    frame = None

                if frame is None:
                    fail_streak += 1
                    if fail_streak >= 30:
                        with self._lock:
                            self.video_ok = False
                            self.video_error = "视频流中断，正在重连..."
                        logger.warning("video stream lost, reconnecting...")
                        cap.release()
                        break
                    time.sleep(0.2)
                    continue
                fail_streak = 0

                try:
                    if self.vision is not None:
                        if frame_i % self.yolo_every_n == 0:
                            last_vis = self.vision.analyze(frame, self.planner.follow_side)
                            with self._lock:
                                self.latest_vision = last_vis
                        vis = last_vis
                        with self._lock:
                            plan = dict(self.latest_plan)
                        out = self.vision.draw_overlay(frame, vis, plan)
                    else:
                        out = frame

                    _, buf = cv2.imencode(
                        ".jpg", out, [int(cv2.IMWRITE_JPEG_QUALITY), self.video_jpeg_quality],
                    )
                    with self._lock:
                        self.latest_frame_jpeg = buf.tobytes()
                        self.frame_seq += 1
                        self.video_ok = True
                        self.video_error = ""
                    frame_i += 1
                except Exception as exc:
                    logger.warning("video process error: %s", exc)

                elapsed = time.perf_counter() - t0
                time.sleep(max(0.0, self._frame_interval - elapsed))

    def _read_latest_frame(self, cap: cv2.VideoCapture) -> Optional[np.ndarray]:
        """丢弃 MJPEG 缓冲旧帧，只取最新一帧。"""
        ok = False
        frame = None
        for _ in range(self.buffer_drain):
            ok, frame = cap.read()
            if not ok:
                break
        return frame if ok else None


STATE: Optional[AppState] = None
# 强引用，防止 create_task 被 GC 提前销毁
_BG_TASKS: set[asyncio.Task] = set()


def get_state() -> AppState:
    global STATE
    if STATE is None:
        cfg_path = ROOT / "config.yaml"
        if not cfg_path.exists():
            cfg_path = ROOT / "config.yaml.example"
        with cfg_path.open("r", encoding="utf-8") as fp:
            STATE = AppState(yaml.safe_load(fp))
    return STATE


def _track_task(task: asyncio.Task) -> asyncio.Task:
    _BG_TASKS.add(task)

    def _done(t: asyncio.Task) -> None:
        _BG_TASKS.discard(t)
        try:
            exc = t.exception()
        except asyncio.CancelledError:
            return
        if exc is not None:
            logger.error("background task failed: %s", exc, exc_info=exc)

    task.add_done_callback(_done)
    return task


async def sensor_ws_client() -> None:
    """主动连接小车 sensor_relay（ws://car:6602），与 mapping/web 一致。"""
    import websockets

    st = get_state()
    url = f"ws://{st.car_ip}:{st.sensor_ws_port}"
    while True:
        try:
            with st._lock:
                st.sensor_ok = False
                st.sensor_error = f"连接中 {url} ..."
            logger.info("connecting sensor ws %s ...", url)
            async with websockets.connect(
                url,
                ping_interval=20,
                ping_timeout=60,
                close_timeout=5,
                max_size=8 * 1024 * 1024,
            ) as ws:
                with st._lock:
                    st.sensor_ok = True
                    st.sensor_error = ""
                logger.info("sensor ws connected: %s", url)
                buffer = ""
                odom_count = 0
                pose_count = 0
                map_count = 0
                first_raw_logged = False
                last_diag = time.time()
                async for raw in ws:
                    try:
                        text = raw.decode("utf-8", errors="replace") if isinstance(raw, bytes) else raw
                        if not first_raw_logged:
                            first_raw_logged = True
                            logger.info("first raw ws msg (first 300 chars): %s", text[:300])
                        buffer += text
                        # 用大括号匹配提取完整帧，不再依赖 # 分隔
                        # 车端帧格式：@XXX{json}# 或 @XXX{json}（可能无 #）
                        while True:
                            # 找到下一个 @ 命令开头
                            idx = -1
                            cmd = None
                            for tag in ("@MAP", "@POSE", "@SCAN", "@ODOM"):
                                pos = buffer.find(tag)
                                if pos >= 0 and (idx < 0 or pos < idx):
                                    idx = pos
                                    cmd = tag
                            if idx < 0:
                                buffer = ""
                                break
                            # 找到 { 开始位置
                            brace_pos = buffer.find("{", idx)
                            if brace_pos < 0:
                                # 没有 {，丢弃 @XXX 前缀
                                buffer = buffer[idx + len(cmd):]
                                continue
                            # 用大括号匹配找到 JSON 结束位置
                            depth = 0
                            end_pos = -1
                            in_string = False
                            escape = False
                            for i in range(brace_pos, len(buffer)):
                                ch = buffer[i]
                                if escape:
                                    escape = False
                                    continue
                                if ch == '\\':
                                    escape = True
                                    continue
                                if ch == '"':
                                    in_string = not in_string
                                    continue
                                if in_string:
                                    continue
                                if ch == '{':
                                    depth += 1
                                elif ch == '}':
                                    depth -= 1
                                    if depth == 0:
                                        end_pos = i
                                        break
                            if end_pos < 0:
                                # JSON 不完整，等更多数据
                                # 但如果 buffer 太大（>500KB），可能是解析卡住了
                                if len(buffer) > 500000:
                                    logger.warning(
                                        "buffer too large (%d chars), clearing. first 200: %s",
                                        len(buffer), buffer[:200],
                                    )
                                    buffer = ""
                                break
                            # 提取完整帧
                            json_str = buffer[brace_pos:end_pos + 1]
                            buffer = buffer[end_pos + 1:]
                            # 跳过可能存在的 # 分隔符
                            if buffer.startswith("#"):
                                buffer = buffer[1:]
                            # 统计
                            if cmd == "@ODOM":
                                odom_count += 1
                                if odom_count == 1:
                                    logger.info("first @ODOM: %s", json_str[:80])
                            elif cmd == "@POSE":
                                pose_count += 1
                                if pose_count == 1:
                                    logger.info("first @POSE: %s", json_str[:80])
                            elif cmd == "@MAP":
                                map_count += 1
                                if map_count == 1:
                                    logger.info("first @MAP: json len=%s", len(json_str))
                                elif map_count <= 5 or map_count % 10 == 0:
                                    logger.info("@MAP #%d: json len=%s", map_count, len(json_str))
                            elif cmd == "@SCAN" and st.scan_count == 0:
                                logger.info("first @SCAN: %s chars", len(json_str))
                            # 直接传 JSON 字符串给 parse_sensor
                            st.parse_sensor_json(cmd, json_str)
                        # 每 5 秒打印一次诊断
                        now = time.time()
                        if now - last_diag >= 5.0:
                            last_diag = now
                            logger.info(
                                "diag: map=%d pose=%d odom=%d scan=%d buf=%d remote_map=%d",
                                map_count, pose_count, odom_count, st.scan_count,
                                len(buffer), st.slam.remote_map_count,
                            )
                    except Exception as exc:
                        logger.warning("sensor frame error: %s", exc)
                logger.info(
                    "sensor ws closed (map=%s, pose=%s, odom=%s, scan=%s)",
                    map_count, pose_count, odom_count, st.scan_count,
                )
        except asyncio.CancelledError:
            raise
        except Exception as exc:
            with st._lock:
                st.sensor_ok = False
                st.sensor_error = str(exc)
            logger.warning("sensor ws error: %s — retry in 2s", exc)
            await asyncio.sleep(2.0)


async def control_loop() -> None:
    """已废弃：控制逻辑移到 control_thread 线程，不阻塞事件循环。"""
    pass


@asynccontextmanager
async def lifespan(_app: FastAPI):
    st = get_state()
    threading.Thread(target=st.video_tick, daemon=True, name="video_tick").start()
    threading.Thread(target=st.control_thread, daemon=True, name="control_thread").start()
    _track_task(asyncio.create_task(sensor_ws_client(), name="sensor_ws_client"))
    cfg_path = ROOT / "config.yaml"
    if not cfg_path.exists():
        cfg_path = ROOT / "config.yaml.example"
    with cfg_path.open("r", encoding="utf-8") as fp:
        port = int(yaml.safe_load(fp).get("server", {}).get("port", 8080))
    logger.info("web UI http://127.0.0.1:%s", port)
    logger.info("sensor client → ws://%s:%s", st.car_ip, st.sensor_ws_port)
    yield
    for task in list(_BG_TASKS):
        task.cancel()
    if _BG_TASKS:
        await asyncio.gather(*_BG_TASKS, return_exceptions=True)
    _BG_TASKS.clear()
    logger.info("background tasks stopped")


app = FastAPI(title="Auto Mapping Web", lifespan=lifespan)


@app.get("/", response_class=HTMLResponse)
async def index() -> HTMLResponse:
    st = get_state()
    html = (ROOT / "templates" / "index.html").read_text(encoding="utf-8")
    html = html.replace("__UI_REFRESH_MS__", str(st.ui_refresh_ms))
    return HTMLResponse(html)


@app.get("/api/status")
async def api_status() -> dict[str, Any]:
    st = get_state()
    with st._lock:
        return {
            "auto_running": st.auto_running,
            "scan_count": st.scan_count,
            "pose": st.slam.pose,
            "has_odom": st.slam.has_odom,
            "has_pose": st.slam.has_pose,
            "has_remote_map": st.slam.remote_map is not None,
            "remote_map_count": st.slam.remote_map_count,
            "slam_scan_count": st.slam.scan_count,
            "plan": st.latest_plan,
            "vision": st.latest_vision,
            "frontier": st.slam.frontier_count(),
            "car_ip": st.car_ip,
            "video_ok": st.video_ok,
            "video_error": st.video_error,
            "sensor_ok": st.sensor_ok,
            "sensor_error": st.sensor_error,
            "frame_seq": st.frame_seq,
            "video_url": f"http://{st.car_ip}:{st.video_port}/video_feed",
            "sensor_url": f"ws://{st.car_ip}:{st.sensor_ws_port}",
        }


@app.post("/api/start")
async def api_start() -> dict[str, str]:
    st = get_state()
    st.auto_running = True
    st.car.connect()
    return {"status": "started"}


@app.post("/api/stop")
async def api_stop() -> dict[str, str]:
    st = get_state()
    st.auto_running = False
    st.car.stop()
    return {"status": "stopped"}


@app.get("/map.png")
async def map_png() -> Response:
    st = get_state()
    return Response(
        st.slam.to_png_bytes(),
        media_type="image/png",
        headers={"Cache-Control": "no-store, no-cache, must-revalidate"},
    )


@app.get("/video.jpg")
async def video_jpg() -> Response:
    st = get_state()
    with st._lock:
        data = st.latest_frame_jpeg
        seq = st.frame_seq
    if not data:
        return Response(b"", media_type="image/jpeg", status_code=204)
    return Response(
        data,
        media_type="image/jpeg",
        headers={
            "Cache-Control": "no-store, no-cache, must-revalidate",
            "X-Frame-Seq": str(seq),
        },
    )


@app.websocket("/ws/ui")
async def ws_ui(ws: WebSocket) -> None:
    await ws.accept()
    st = get_state()
    st._clients.add(ws)
    try:
        while True:
            with st._lock:
                payload = {
                    "scan_count": st.scan_count,
                    "pose": st.slam.pose,
                    "has_odom": st.slam.has_odom,
                    "has_pose": st.slam.has_pose,
                    "has_remote_map": st.slam.remote_map is not None,
                    "remote_map_count": st.slam.remote_map_count,
                    "slam_scan_count": st.slam.scan_count,
                    "plan": st.latest_plan,
                    "vision": {
                        k: st.latest_vision.get(k)
                        for k in ("valid", "follow_wall", "front_wall", "wall_dist_px", "corner_hint")
                    },
                    "auto_running": st.auto_running,
                    "video_ok": st.video_ok,
                    "video_error": st.video_error,
                    "sensor_ok": st.sensor_ok,
                    "sensor_error": st.sensor_error,
                    "frame_seq": st.frame_seq,
                    "car_ip": st.car_ip,
                }
            await ws.send_json(payload)
            await asyncio.sleep(0.15)
    except WebSocketDisconnect:
        pass
    finally:
        st._clients.discard(ws)


def main() -> None:
    import uvicorn
    cfg_path = ROOT / "config.yaml"
    if not cfg_path.exists():
        cfg_path = ROOT / "config.yaml.example"
    with cfg_path.open("r", encoding="utf-8") as fp:
        cfg = yaml.safe_load(fp)
    host = cfg.get("server", {}).get("host", "0.0.0.0")
    port = int(cfg.get("server", {}).get("port", 8080))
    # 直接传 app 对象，避免字符串导入导致 lifespan 双启
    uvicorn.run(app, host=host, port=port, reload=False)


if __name__ == "__main__":
    main()
