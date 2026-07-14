#!/usr/bin/env python3
"""轻量传感转发：ROS 2 /scan、/odom、tf(map→base_link) → WebSocket @SCAN/@ODOM/@POSE。

订阅 Docker 建图栈（rclpy）中的话题，降采样后推给 PC Web 后端。
@POSE 来自 tf map→base_link，是 SLAM 校正后的位姿（和 rviz2 一致），
PC 端用它来做栅格地图的坐标变换，避免 odom 漂移导致墙"挪动"。
与 app.py（6000/6500 遥控）无关，无需 ROS 1 Master。
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
import subprocess
import threading
import time
from pathlib import Path
from typing import Any, Optional, Set

import yaml

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("sensor_relay")

CONFIG_PATH = Path(__file__).parent / "config.yaml"

_ros_ready = False
_ros_error = ""
_scan_count = 0


def load_config() -> dict[str, Any]:
    with CONFIG_PATH.open("r", encoding="utf-8") as fp:
        return yaml.safe_load(fp)


def bootstrap_ros2_environment(cfg: dict[str, Any]) -> bool:
    """自动加载 ROS 2 环境（等效 source /opt/ros/foxy/setup.bash）。"""
    try:
        import rclpy  # noqa: F401

        return True
    except ImportError:
        pass

    candidates: list[Path] = []
    custom = cfg.get("ros_setup")
    if custom:
        candidates.append(Path(str(custom)))
    for dist in ("foxy", "humble", "iron", "galactic"):
        candidates.append(Path(f"/opt/ros/{dist}/setup.bash"))

    seen: set[str] = set()
    for setup in candidates:
        path = str(setup)
        if path in seen or not setup.is_file():
            continue
        seen.add(path)
        cmd = (
            f'source "{setup}" && python3 -c "import json,os; print(json.dumps(dict(os.environ)))"'
        )
        try:
            proc = subprocess.run(
                ["bash", "-c", cmd],
                capture_output=True,
                text=True,
                timeout=30,
            )
            if proc.returncode != 0:
                logger.debug("setup %s failed: %s", setup, proc.stderr.strip())
                continue
            env = json.loads(proc.stdout)
            os.environ.update(env)
            import rclpy  # noqa: F401

            logger.info("ROS 2 environment loaded from %s", setup)
            return True
        except Exception as exc:
            logger.warning("bootstrap %s: %s", setup, exc)

    return False


class SensorRelay:
    def __init__(self, cfg: dict[str, Any]) -> None:
        self.cfg = cfg
        self.clients: Set[Any] = set()
        self._latest_scan: Optional[dict[str, Any]] = None
        self._latest_odom: Optional[dict[str, Any]] = None
        self._latest_pose: Optional[dict[str, Any]] = None
        self._pose_count = 0
        self._lock = threading.Lock()

    def on_scan(self, msg: Any) -> None:
        global _scan_count, _ros_ready
        _scan_count += 1
        _ros_ready = True
        max_ranges = int(self.cfg.get("max_ranges", 360))
        ranges = list(msg.ranges)
        if len(ranges) > max_ranges:
            step = max(1, len(ranges) // max_ranges)
            ranges = ranges[::step][:max_ranges]
            angle_min = float(msg.angle_min)
            angle_inc = float(msg.angle_increment) * step
        else:
            angle_min = float(msg.angle_min)
            angle_inc = float(msg.angle_increment)

        payload = {
            "ranges": [float(r) if r == r else 0.0 for r in ranges],
            "angle_min": angle_min,
            "angle_max": angle_min + angle_inc * (len(ranges) - 1) if ranges else angle_min,
            "angle_increment": angle_inc,
            "range_min": float(msg.range_min),
            "range_max": float(msg.range_max),
            "t": time.time(),
        }
        with self._lock:
            self._latest_scan = payload
        if _scan_count == 1:
            logger.info("first /scan received (%s points)", len(ranges))

    def on_odom(self, msg: Any) -> None:
        import math

        p = msg.pose.pose.position
        q = msg.pose.pose.orientation
        siny = 2.0 * (q.w * q.z + q.x * q.y)
        cosy = 1.0 - 2.0 * (q.y * q.y + q.z * q.z)
        theta = math.atan2(siny, cosy)
        payload = {
            "x": float(p.x),
            "y": float(p.y),
            "theta": float(theta),
            "vx": float(msg.twist.twist.linear.x),
            "vy": float(msg.twist.twist.linear.y),
            "t": time.time(),
        }
        with self._lock:
            self._latest_odom = payload

    async def register(self, ws: Any) -> None:
        self.clients.add(ws)
        logger.info("client connected, total=%s", len(self.clients))
        with self._lock:
            scan = self._latest_scan
            odom = self._latest_odom
            pose = self._latest_pose
        try:
            if scan:
                await ws.send(f"@SCAN{json.dumps(scan, separators=(',', ':'))}#")
            if odom and self.cfg.get("use_odom", True):
                await ws.send(f"@ODOM{json.dumps(odom, separators=(',', ':'))}#")
            if pose and self.cfg.get("use_pose", True):
                await ws.send(f"@POSE{json.dumps(pose, separators=(',', ':'))}#")
        except Exception:
            pass

    async def unregister(self, ws: Any) -> None:
        self.clients.discard(ws)
        logger.info("client disconnected, total=%s", len(self.clients))

    async def broadcast_loop(self) -> None:
        hz = float(self.cfg.get("publish_hz", 5))
        interval = 1.0 / max(hz, 0.5)
        last_warn = 0.0
        while True:
            await asyncio.sleep(interval)
            with self._lock:
                scan = self._latest_scan
                odom = self._latest_odom
                pose = self._latest_pose
            if _scan_count == 0 and time.time() - last_warn > 15:
                last_warn = time.time()
                logger.warning(
                    "no /scan yet (%s). Use ./start_relay.sh 30 or ./start_relay_docker.sh 30",
                    _ros_error or "waiting for ROS2 topics",
                )
            if not self.clients:
                continue
            if scan:
                frame = f"@SCAN{json.dumps(scan, separators=(',', ':'))}#"
                await self._send_all(frame)
            if odom and self.cfg.get("use_odom", True):
                frame = f"@ODOM{json.dumps(odom, separators=(',', ':'))}#"
                await self._send_all(frame)
            # SLAM 校正后的 pose（map 坐标系），每帧都发
            if pose and self.cfg.get("use_pose", True):
                frame = f"@POSE{json.dumps(pose, separators=(',', ':'))}#"
                await self._send_all(frame)

    async def _send_all(self, message: str) -> None:
        dead: list[Any] = []
        for ws in self.clients:
            try:
                await ws.send(message)
            except Exception:
                dead.append(ws)
        for ws in dead:
            self.clients.discard(ws)


def _make_pose_lookup(tf_buffer: Any, relay: SensorRelay, map_frame: str, base_frame: str):
    """返回一个定时回调：查 tf map→base_link → 更新 relay._latest_pose。"""
    import math

    def _cb() -> None:
        if tf_buffer is None:
            return
        try:
            from rclpy.time import Time

            trans = tf_buffer.lookup_transform(map_frame, base_frame, Time())
        except Exception:
            return
        t = trans.transform.translation
        r = trans.transform.rotation
        siny = 2.0 * (r.w * r.z + r.x * r.y)
        cosy = 1.0 - 2.0 * (r.y * r.y + r.z * r.z)
        theta = math.atan2(siny, cosy)
        payload = {
            "x": float(t.x),
            "y": float(t.y),
            "theta": float(theta),
            "frame": map_frame,
            "t": time.time(),
        }
        with relay._lock:
            relay._latest_pose = payload
        if relay._pose_count == 0:
            logger.info(
                "first tf %s→%s pose: x=%.2f y=%.2f θ=%.2f",
                map_frame, base_frame, t.x, t.y, theta,
            )
        relay._pose_count += 1

    return _cb


def _apply_ros_env(cfg: dict[str, Any]) -> None:
    domain = cfg.get("ros_domain_id")
    if domain is not None:
        os.environ["ROS_DOMAIN_ID"] = str(domain)
    logger.info(
        "ROS_DOMAIN_ID=%s (must match Docker launch stack)",
        os.environ.get("ROS_DOMAIN_ID", "0"),
    )


def start_ros2(relay: SensorRelay, cfg: dict[str, Any]) -> None:
    global _ros_ready, _ros_error
    retry_sec = float(cfg.get("ros_retry_sec", 10))

    while True:
        if not bootstrap_ros2_environment(cfg):
            _ros_error = (
                "rclpy not found on host — run ./start_relay.sh 30 "
                "or ./start_relay_docker.sh 30"
            )
            logger.error(_ros_error)
            time.sleep(retry_sec)
            continue

        try:
            import rclpy
            from nav_msgs.msg import Odometry
            from rclpy.executors import SingleThreadedExecutor
            from rclpy.node import Node
            from sensor_msgs.msg import LaserScan
        except ImportError as exc:
            _ros_error = str(exc)
            logger.error("import rclpy failed: %s", exc)
            time.sleep(retry_sec)
            continue

        _apply_ros_env(cfg)

        map_frame = cfg.get("map_frame", "map")
        base_frame = cfg.get("base_frame", "base_link")
        use_pose = cfg.get("use_pose", True)

        class RelayNode(Node):
            def __init__(self) -> None:
                global _ros_ready
                super().__init__("mapping_sensor_relay")
                scan_topic = cfg.get("scan_topic", "/scan")
                odom_topic = cfg.get("odom_topic", "/odom")
                qos = int(cfg.get("qos_depth", 10))
                self.create_subscription(LaserScan, scan_topic, relay.on_scan, qos)
                if cfg.get("use_odom", True):
                    self.create_subscription(Odometry, odom_topic, relay.on_odom, qos)
                logger.info("ROS2 subscribed scan=%s odom=%s", scan_topic, odom_topic)
                _ros_ready = True

        try:
            if not rclpy.ok():
                rclpy.init()
            node = RelayNode()
            executor = SingleThreadedExecutor()
            executor.add_node(node)

            # tf2 listener：查 map→base_link 得 SLAM 校正后 pose
            tf_buffer = None
            if use_pose:
                try:
                    from tf2_ros import Buffer, TransformListener

                    tf_buffer = Buffer()
                    TransformListener(tf_buffer, node, spin_thread=False)
                    node.create_timer(
                        0.2,
                        _make_pose_lookup(tf_buffer, relay, map_frame, base_frame),
                    )
                    logger.info(
                        "tf listener ready: %s→%s @5Hz (SLAM-corrected pose)",
                        map_frame, base_frame,
                    )
                except ImportError:
                    logger.warning(
                        "tf2_ros not available — @POSE disabled, "
                        "PC will fall back to /odom (may drift)"
                    )

            logger.info("ROS2 spin started")
            executor.spin()
            return
        except Exception as exc:
            _ros_error = str(exc)
            logger.error("ROS2 thread failed: %s — retry in %ss", exc, retry_sec)
            try:
                if rclpy.ok():
                    rclpy.shutdown()
            except Exception:
                pass
            time.sleep(retry_sec)


async def main_async() -> None:
    try:
        import websockets
    except ImportError as exc:
        raise SystemExit("pip install websockets") from exc

    cfg = load_config()
    relay = SensorRelay(cfg)
    host = cfg.get("ws_host", "0.0.0.0")
    port = int(cfg.get("ws_port", 6602))

    async def handler(ws: Any) -> None:
        await relay.register(ws)
        try:
            await ws.wait_closed()
        except Exception:
            pass
        finally:
            await relay.unregister(ws)

    ros_thread = threading.Thread(target=start_ros2, args=(relay, cfg), daemon=True)
    ros_thread.start()

    asyncio.create_task(relay.broadcast_loop())

    async with websockets.serve(handler, host, port, ping_interval=20, ping_timeout=60):
        logger.info("sensor relay listening on ws://%s:%s", host, port)
        logger.info("tip: ./start_relay.sh 30  OR  ./start_relay_docker.sh 30")
        await asyncio.Future()


def main() -> None:
    try:
        asyncio.run(main_async())
    except KeyboardInterrupt:
        logger.info("stopped")


if __name__ == "__main__":
    main()
