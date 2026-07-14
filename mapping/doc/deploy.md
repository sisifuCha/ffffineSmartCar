# 部署步骤



## 架构说明



| 组件 | ROS | 作用 |

|------|-----|------|

| Docker 建图 launch | **ROS 2** | 发布 `/scan`、`/odom` |

| `sensor_relay.py` | **ROS 2 (rclpy)** | 订阅上述话题 → WebSocket :6602 |

| `app.py`（可选） | 无 ROS | TCP 6000 遥控、6500 视频 |



**不需要** ROS 1 的 `roscore` (11311)，也**不需要**为建图去起 `app.py`。



## 前置检查（Jetson）



```bash

source /opt/ros/foxy/setup.bash

export ROS_DOMAIN_ID=30          # 与 Docker 一致，按实车修改



# 雷达（ROS2）

ros2 topic echo /scan --once



# 里程计（可选）

ros2 topic echo /odom --once



# 摄像头（若用 app.py）

curl -I http://127.0.0.1:6500/index2

```



若 `/scan` 话题名不同，改 [car/config.yaml](../car/config.yaml) 里 `scan_topic`。



## 拷贝文件到小车



将仓库 `mapping/car/` 拷到 Jetson，例如 `/home/jetson/smartcar/mapping/car/`。



## 启动主车



```bash

# 1. 先确保 Docker / launch 已在跑，且 ros2 topic list 能看到 /scan



# 2. 启动传感转发（DOMAIN 与 Docker 一致）

cd ~/smartcar/mapping/car

chmod +x start_relay.sh

./start_relay.sh 30

```



或手动：



```bash

source /opt/ros/foxy/setup.bash

export ROS_DOMAIN_ID=30

pip3 install -r requirements.txt

python3 sensor_relay.py

```



也可在 `config.yaml` 里设置 `ros_domain_id: 30`，则不必每次 export。



成功标志：



- `ROS2 subscribed scan=/scan odom=/odom`

- `first /scan received`

- `sensor relay listening on ws://0.0.0.0:6602`



### 在 Docker 内运行（可选）



若宿主机 DOMAIN 对不上，可进容器跑 relay：



```bash

docker exec -it mn bash

source /opt/ros/foxy/setup.bash

cd /path/to/mapping/car

python3 sensor_relay.py

```



PC 仍连 **宿主机 IP:6602**（容器需 `-p 6602:6602` 或 `--network host`）。



## 启动 Windows Web



1. 编辑 `mapping/web/config.yaml`：



```yaml

car:

  ip: "192.168.137.174"   # 主车 IP

  tcp_port: 6000

  video_port: 6500

  sensor_ws_port: 6602

```



2. 安装并运行：



```bash

cd mapping/web

pip install -r requirements.txt

python -m backend.main

```



3. 浏览器打开 http://127.0.0.1:8080，确认 **传感器✓** 后 **开始建图**。



## 防火墙



- PC 需能访问小车 `6602`（必须）、`6000`/`6500`（遥控/视频时）



## 常见问题



| 现象 | 处理 |

|------|------|

| `rclpy not found` | `source /opt/ros/foxy/setup.bash` 后再运行 |

| `no /scan yet` | Docker launch 是否在跑；`ROS_DOMAIN_ID` 是否与 Docker 一致 |

| `Unable to register with master 11311` | 旧版 rospy 代码；请更新为当前 rclpy 版 `sensor_relay.py` |

| Web `传感器✗` | relay 是否在跑；PC `ping` 小车；防火墙 6602 |

| 地图不更新 | `ros2 topic echo /scan --once`；relay 日志应有 `first /scan received` |

| 车不动 | 需 `app.py` 或底盘桥接占 6000；建图时不要手机 App 同连 6000 |

