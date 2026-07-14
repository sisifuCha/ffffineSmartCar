# mapping 传感与控制协议

小车端 `sensor_relay.py` 订阅 **ROS 2** 话题 `/scan`、`/odom`（Docker 建图栈），经 WebSocket **:6602** 推给 PC。无需 ROS 1 Master。

## 小车 → PC（WebSocket :6602）

每条消息以 `#` 结尾，JSON 紧跟前缀后。

### @SCAN

```text
@SCAN{"ranges":[1.2,1.1,...],"angle_min":-3.14159,"angle_max":3.14159,"angle_increment":0.017,"range_min":0.05,"range_max":12.0,"t":1710000000.12}#
```

| 字段 | 含义 |
|------|------|
| ranges | 距离数组（米），与 ROS LaserScan 一致 |
| angle_* | 弧度 |
| t | 时间戳（秒） |

### @ODOM

```text
@ODOM{"x":0.1,"y":0.0,"theta":0.05,"vx":0.0,"vy":0.0,"t":1710000000.12}#
```

| 字段 | 含义 |
|------|------|
| x, y, theta | 位姿（米、弧度） |
| vx, vy | 线速度（可选） |
| t | 时间戳 |

## PC → 小车（TCP :6000）

与 [doc/ros_api.md](../../doc/ros_api.md) 相同，`$...#` 帧。

Web 建图常用：

| 用途 | 示例 |
|------|------|
| 摇杆速度 cmd 10 | `$01100A00000064#`（vx=0, vy=0） |
| 停车 cmd 15 | `$011504001A#` |

编码规则见 App [CarEncode.ets](../../entry/src/main/ets/CarUtill/CarEncode.ets)。

## Web 后端 → 浏览器（WebSocket /ws/map）

JSON 消息（无 `#` 包裹）：

```json
{"type":"map","w":400,"h":400,"resolution":0.05,"origin":[-10,-10],"data":[0,1,2,...],"pose":{"x":0,"y":0,"theta":0}}
```

`data`：0=未知，1=空闲，2=障碍。

## 视觉沿墙（PC 端 OpenCV）

小车摄像头 HTTP 流由 PC 拉取（`vision.stream_urls`），在画面下半部检测竖直边缘（墙/栏杆），保持 `target_distance_px` 横向距离并前进。

### HTTP API

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/wallfollow/start` | body: `{"side":"left"|"right","target_distance_px":120}` |
| POST | `/api/wallfollow/stop` | 停止沿墙并停车 |
| GET | `/api/vision/debug.jpg` | 带边缘标注的 JPEG 预览 |
| GET | `/api/status` | 含 `wall_following`、`vision.wall_found`、`vision.distance_px` |

控制循环约 10Hz，发送 cmd10（vx 横移、vy 前进）。前方画面边缘占比超过 `obstacle_stop_ratio` 时停车。
