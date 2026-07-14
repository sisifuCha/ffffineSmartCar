#!/bin/bash
# 在 Jetson 上启动 sensor_relay（ROS 2）
# 用法: ./start_relay.sh [ROS_DOMAIN_ID]

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

if [ -f /opt/ros/foxy/setup.bash ]; then
  source /opt/ros/foxy/setup.bash
elif [ -f /opt/ros/humble/setup.bash ]; then
  source /opt/ros/humble/setup.bash
else
  echo "ROS 2 not found under /opt/ros/" >&2
  exit 1
fi

if [ -n "$1" ]; then
  export ROS_DOMAIN_ID="$1"
fi

echo "ROS_DOMAIN_ID=${ROS_DOMAIN_ID:-0}"
pip3 install -r requirements.txt -q 2>/dev/null || true
exec python3 sensor_relay.py
