#!/bin/bash
# 在 Docker 容器内启动 sensor_relay（ROS2 /scan 在容器里时用）
# 用法: ./start_relay_docker.sh [ROS_DOMAIN_ID] [容器名]
# 要求: 容器 --network host，或已映射 -p 6602:6602

set -e
DOMAIN="${1:-30}"
CONTAINER="${2:-mn}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CAR_DIR="$SCRIPT_DIR"

if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  echo "container '$CONTAINER' not running. docker ps" >&2
  exit 1
fi

echo "ROS_DOMAIN_ID=$DOMAIN container=$CONTAINER"
echo "relay dir=$CAR_DIR"

docker exec \
  -e ROS_DOMAIN_ID="$DOMAIN" \
  "$CONTAINER" \
  bash -lc "
    set -e
    source /opt/ros/foxy/setup.bash 2>/dev/null || source /opt/ros/humble/setup.bash
    pip3 install -q websockets PyYAML 2>/dev/null || true
    cd '$CAR_DIR'
    exec python3 sensor_relay.py
  "
