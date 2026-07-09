# 双车编排（车端）

## 端口分工

| 端口 | 作用 |
|------|------|
| **6000** | 手机 → 主车，由**现有 ROS** 监听（不变） |
| **6001** | 主车 → 从车**车际 TCP**（RELAY / ACK） |

主车**不**监听 6001；主车作为客户端连从车的 6001。  
从车运行 `slave_gateway.py` 监听 6001。

## 部署

### 主车（ROS 已占 6000）

1. 把 `orchestrator.py`、`protocol.py`、`config_master.json` 放到 `/home/jetson/smartcar/`（**不必塞进 ROS 源码目录**）
2. ROS **启动时** `init` 一次；**执行完** `$...#` 后调 `get().relay_command(payload)` 转发从车
3. 详见 [ros_integration.md](./ros_integration.md)（已有 ROS 解析时只加几行）
4. **不要**再起任何服务占 6000  

### 从车

```bash
cd car
python3 slave_gateway.py    # 监听 6001，读 config_slave.json
```

### 手机 App

- 仍连主车 **IP:6000**  
- 开启双车模式，填写从车 IP（App 通过 `@CONFIG` 告诉主车从车地址）

## 文件

| 文件 | 说明 |
|------|------|
| `master_phone_server.py` | 主车监听 **6000**（车上无 ROS 时用） |
| `slave_gateway.py` | 从车监听 **6001** |
| `protocol.py` | RELAY / ACK / @STATUS |
| `ros_integration.md` | 集成说明 |

协议详见 [doc/ros_api.md](../doc/ros_api.md)。

**从零部署请看：[doc/双车部署操作全流程.md](../doc/双车部署操作全流程.md)**
