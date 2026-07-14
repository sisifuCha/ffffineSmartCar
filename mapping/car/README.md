# 小车端 — 传感转发

仅运行 `sensor_relay.py`，**不建图、不导航**。

```bash
pip3 install -r requirements.txt
python3 sensor_relay.py
```

监听 WebSocket `ws://0.0.0.0:6602`，推送 `@SCAN` / `@ODOM` 帧。详见 [../doc/protocol.md](../doc/protocol.md)。
