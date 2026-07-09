# 主车已有 ROS 解析指令 — 怎么接双车转发

## 先搞清楚：你要加的是什么

你现在的流程：

```
手机 ──:6000──> ROS（收包、解析 $...#、动车）   ← 这套不用动
```

双车只是在主车 **执行完** 之后，**同一条指令再抄送一份** 给从车：

```
手机 ──:6000──> ROS 执行（照旧）
                    │
                    └──:6001──> 从车 slave_gateway 执行
```

所以：**不用把文件塞进 ROS 源码目录**，也不用换掉 ROS 里已有的解析逻辑。

---

## 文件放哪

推荐目录（与 ROS 工程并列）：

```
/home/jetson/smartcar/
├── orchestrator.py
├── protocol.py
├── config_master.json    ← 改 slave_ip
└── ros_bridge.py         ← 可选，少写几行 import
```

ROS 里用 `sys.path.insert(0, "/home/jetson/smartcar")` 能 `import` 到即可。

主车 **不需要** `command_executor.py`（那是给从车用的）。

从 Desktop 拷过来的步骤见 [doc/双车部署操作全流程.md](../doc/双车部署操作全流程.md) 第 2.3 节。

---

## 最少改法（推荐）

### 1. ROS 启动时（只执行一次）

```python
import sys
sys.path.insert(0, "/home/jetson/smartcar")

from ros_bridge import init, on_phone_connected, on_phone_disconnected

init("/home/jetson/smartcar/config_master.json")
```

### 2. 手机连上 TCP 6000 时

在你现有的 `accept` / `on_connect` 里加：

```python
on_phone_connected(lambda data: conn.sendall(data.encode("utf-8")))
```

断开时：

```python
on_phone_disconnected()
```

### 3. 收到并执行完 `$...#` 之后（关键，只加这一行）

在你 **原来已经解析、已经动车** 的代码后面：

```python
from ros_bridge import get

payload = "$011504011B#"   # 举例：你 ROS 里拿到的完整指令字符串
# ... 你原有的解析和执行（保持不动）...

get().relay_command(payload)   # 新增：转发给从车 6001
```

`relay_command` **不会**再执行一遍电机控制，只负责车际 TCP 转发。

### 4. 收到 `@CONFIG` 时（App 开双车模式会发）

如果收包循环里能识别以 `@` 开头的帧：

```python
from ros_bridge import get

if frame.startswith("@"):
    get().handle_phone_frame(frame)
```

也可以只靠 `config_master.json` 里的 `slave_ip`，但 App 连接后发的 `@CONFIG` 会覆盖配置。

---

## 从车

```bash
cd /home/jetson/smartcar
python3 slave_gateway.py   # 监听 6001
```

从车用 `command_executor.py` 执行转发来的 `$...#`（默认只打日志，要动车需接电机）。

---

## 端口分工

| 端口 | 用途 | 谁监听 |
|------|------|--------|
| **6000** | 手机 → 主车 | **你的 ROS**（不变） |
| **6001** | 主车 → 从车 | **从车** `slave_gateway.py` |

---

## 可选：process_phone_buffer

如果你愿意改收包循环、统一走一个入口，可以用：

```python
buffer, handled = process_phone_buffer(buffer, your_existing_ros_execute)
```

它会：先调你传入的 `your_existing_ros_execute` 执行 `$...#`，再 `relay_command` 转发。

**已有完整解析流程时，不必用这个**；直接在你执行完的地方调 `get().relay_command(payload)` 更简单。

---

## config_master.json

```json
{
  "slave_ip": "192.168.1.12",
  "car_tcp_port": 6001,
  "dual_mode": true
}
```

`slave_ip` 改成从车真实 IP，与 App 里填的从车 IP 一致即可。
