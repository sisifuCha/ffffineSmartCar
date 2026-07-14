# Windows PC 自动建图 Web 服务

接收小车雷达 + 视频，YOLO 识别墙体，SLAM 建图，自动下发前后左右控制。

## 部署（Windows）

1. 将整个 `auto_mapping_web` 文件夹复制到 PC，例如：
   `D:\oh-ai-car-ros-app\mapping\auto_mapping_web`

2. 安装依赖并配置：

```powershell
cd D:\oh-ai-car-ros-app\mapping\auto_mapping_web
copy config.yaml.example config.yaml
# 编辑 config.yaml：car.ip = 小车 IP；car.sensor_ws_port = 6602
pip install -r requirements.txt
```

3. （可选）YOLO 权重：将权重路径写入 `config.yaml` 的 `vision.yolo_weights`。

4. 启动：

```powershell
python main.py
# 或双击 start.bat
```

5. 浏览器打开：**http://127.0.0.1:8080**

## 使用流程

```
1. 小车运行 mapping/car 的 sensor_relay（./start_relay.sh 或 docker）
2. 小车视频/遥控服务已就绪（:6500 / :6000）
3. PC 运行 python main.py（主动连 ws://小车:6602）
4. 浏览器点「开始自动建图」
5. 观察：左侧 SLAM 地图应出现黑墙/白空闲区 + 红点
```

状态栏 **雷达帧** 持续增加，说明 `@SCAN` 已进 SLAM。

## 界面说明

| 区域 | 内容 |
|------|------|
| SLAM 地图 | 雷达 + 里程计实时占用栅格（白=空闲，黑=墙，灰=未知） |
| YOLO 视觉 | 检测框 + 当前动作 |
| 状态栏 | 雷达/视频连接、位姿、离墙距离 |
| 动作 | FORWARD / TURN_LEFT / TURN_RIGHT / STOP |

## 控制协议

与手机 App 相同，经 TCP 6000 发送 `$...#`：

- `FORWARD` → 前进
- `TURN_LEFT` / `TURN_RIGHT` → 原地转弯
- `FORWARD_SLOW` → 慢速前进
- `STOP` → 停止

决策逻辑见 `wall_planner.py`（前方硬安全门 + 侧向沿墙）。

## 端口

| 端口 | 方向 | 用途 |
|------|------|------|
| 8080 | PC 监听 | Web 界面 |
| 6602 | 小车监听，PC 连接 | sensor_relay `@SCAN`/`@ODOM` |
| 6500 | 小车 | PC 拉取视频 |
| 6000 | 小车 | PC 下发控制 |
