# 本地 Web 自动建图 + 视觉沿墙



小车只转发传感器；**建图、探索、视觉沿墙、控制**在 Windows PC 的 Web 端完成。



## 目录



| 目录 | 部署位置 | 作用 |

|------|----------|------|

| [car/](car/) | 主车 Jetson | `sensor_relay.py` 订阅 ROS2 `/scan`、`/odom` → WebSocket :6602 |

| [web/](web/) | Windows PC | FastAPI + 浏览器：建图、自动探索、**视觉沿墙/栏杆**、遥控 |

| [doc/](doc/) | 文档 | 协议与部署 |



## 快速启动（顺序很重要）



### 1. 主车（Jetson）— 先 ROS2 建图栈，再 sensor_relay



**不需要** `app.py` / `roscore`。雷达在 **Docker ROS2 launch** 里。



```bash

# 终端 1：你的建图/传感 launch（示例，按实车脚本为准）

# docker exec ... ros2 launch ...  或  ./run.sh



# 自检：应有 /scan

source /opt/ros/foxy/setup.bash

export ROS_DOMAIN_ID=30    # 与 Docker 一致

ros2 topic echo /scan --once



# 终端 2：传感转发 → PC

cd ~/smartcar/mapping/car

./start_relay.sh 30        # 参数为 ROS_DOMAIN_ID，或已在 config.yaml 里配置

# 或: source /opt/ros/foxy/setup.bash && export ROS_DOMAIN_ID=30 && python3 sensor_relay.py

```



成功标志：



- `ROS2 subscribed scan=/scan odom=/odom`

- `first /scan received`

- `sensor relay listening on ws://0.0.0.0:6602`



遥控/视频（可选，与建图传感无关）：



- `app.py` → TCP **6000**、摄像头 **6500**



### 2. Windows PC



编辑 [web/config.yaml](web/config.yaml) 中的 `car.ip` 与 `vision` 段，然后：



```bash

cd mapping/web

pip install -r requirements.txt

python -m backend.main

```



浏览器打开：**http://127.0.0.1:8080**



页面顶部会显示 `传感器✓/✗` 和 `视频✓/✗`。传感器 ✓ 后再点 **开始建图**。



### 3. 视觉沿墙/栏杆



1. 确认状态栏 **视频✓**（视频依赖 `app.py` 或独立摄像头服务）

2. 设置 **保持距离(px)**（默认 120）

3. 点 **沿左墙走** / **沿右墙走**



## 端口



| 端口 | 用途 |

|------|------|

| 6000 | 小车运动控制（Web 后端发 `$...#`，通常 app.py） |

| 6500 | 摄像头 HTTP（通常 app.py） |

| 6602 | 传感器 WebSocket（`sensor_relay.py`） |

| 8080 | 本机 Web 界面 |



建图/沿墙时请**不要**同时用手机 App 连 6000 遥控。



详细步骤见 [doc/deploy.md](doc/deploy.md)。

