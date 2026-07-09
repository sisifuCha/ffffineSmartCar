# 智慧小车 ROS 对接版本

## 测试环境

```
DevEco Studio 4.1 Release
构建版本：4.1.0.400, built on April 9, 2024
Build #DS-223.8617.56.36.410400
Runtime version: 17.0.6+10-b829.5 amd64
```

## 项目原型图

### 网络配置界面（NetworkSettings）

![NetworkSettings.png](./doc/prototype/NetworkSettings.png)

### 主页界面（Index）

![Index.png](./doc/prototype/Index.png)

### 麦克纳姆轮界面（MecanumWheel）

![MecanumWheel.png](./doc/prototype/MecanumWheel.png)

### 控制界面状态1（RemoteControl1）

![RemoteControl1.png](./doc/prototype/RemoteControl1.png)

### 控制界面状态2（RemoteControl2）

![RemoteControl2.png](./doc/prototype/RemoteControl2.png)

## ROS API

与 Ros 对接的API看
[Ros_api](./doc/ros_api.md)

## HTTP API

本项目只使用了一个http 接口，访问,相应的接口可以获取直播画面

## 文件结构

```
SmartCar
├─ 📁AppScope                                   
│  ├─ 📁resources
│  │  └─ 📁base                 
│  │     ├─ 📁element
│  │     │  └─ 📄string.json
│  │     └─ 📁media
│  │        └─ 📄app_icon.png
│  └─ 📄app.json5
├─ 📁doc                                    # 文档目录
│  ├─ 📁prototype                           # 原型图目录
│  │  ├─ 📄Index.png
│  │  ├─ 📄MecanumWheel.png
│  │  ├─ 📄NetworkSettings.png
│  │  ├─ 📄RemoteControl1.png
│  │  └─ 📄RemoteControl2.png 
│  └─ 📄ros_api.md                          # ROS API 文档
├─ 📁entry
│  ├─ 📁src
│  │  ├─ 📁main
│  │  │  ├─ 📁ets
│  │  │  │  ├─ 📁CarUtill                   # 小车通信工具包                  
│  │  │  │  │  ├─ 📄CarApi.ets              # 小车通信API 
│  │  │  │  │  ├─ 📄CarEncode.ets           # 小车通信编码工具  
│  │  │  │  │  └─ 📄CarEnum.ets             # 小车通信状态枚举
│  │  │  │  ├─ 📁components                 # 组件包
│  │  │  │  │  ├─ 📄CarBtnComponents.ets    # 小车按钮组件
│  │  │  │  │  ├─ 📄CarRockerComponents.ets # 小车摇杆组件
│  │  │  │  │  └─ 📄VideoComponents.ets     # 视频组件
│  │  │  │  ├─ 📁entryability               # 入口Ability
│  │  │  │  │  └─ 📄EntryAbility.ets        # 入口Ability
│  │  │  │  ├─ 📁img                        # 图片资源
│  │  │  │  │  ├─ 📄remote.svg              # 摇杆控制图
│  │  │  │  │  └─ 📄remote_background.svg   # 摇杆控制背景图
│  │  │  │  ├─ 📁pages                      # 页面包
│  │  │  │  │  ├─ 📄Index.ets               # 主页
│  │  │  │  │  ├─ 📄MecanumWheel.ets        # 麦克纳姆轮页
│  │  │  │  │  ├─ 📄NetworkSettings.ets     # 网络配置页
│  │  │  │  │  └─ 📄RemoteControl.ets       # 遥控页
│  │  │  │  ├─ 📁styles                     # 样式包
│  │  │  │  │  └─ 📄styles.ets              # 样式
│  │  │  │  ├─ 📁tcp                        # TCP 通信包
│  │  │  │  │  ├─ 📄TCPClientManager.ets        # TCP 客户端管理
│  │  │  │  │  ├─ 📄TCPClientReceiveUtils.ets   # TCP 客户端接收工具
│  │  │  │  │  └─ 📄TCPClientSendUtils.ets      # TCP 客户端发送工具
│  │  │  │  └─ 📁utils                      # 工具包
│  │  │  │     ├─ 📄MyUtils.ets             # 工具包
│  │  │  │     ├─ 📄PreferencesUtils.ets    # 偏好设置工具
│  │  │  │     └─ 📄ScreenUtils.ets         # 屏幕工具
│  │  │  ├─ 📁resources
│  │  │  │  ├─ 📁base
│  │  │  │  │  ├─ 📁element
│  │  │  │  │  │  ├─ 📄color.json            # 颜色
│  │  │  │  │  │  ├─ 📄font_color.json       # 字体颜色
│  │  │  │  │  │  ├─ 📄font_size_.json       # 字体大小
│  │  │  │  │  │  ├─ 📄radius_size.json      # 圆角大小
│  │  │  │  │  │  └─ 📄string.json           # 字符串
│  │  │  │  │  └─ 📁profile
│  │  │  │  │     └─ 📄main_pages.json       # 页面配置
├─ 📁Rocker
│  ├─ 📁src
│  │  └─ 📁main
│  │     ├─ 📁ets
│  │     │  └─ 📁components
│  │     │     ├─ 📁RockerUtils                 # 摇杆工具包
│  │     │     │  ├─ 📄RockerDrawUtils.ets      # 摇杆绘制工具
│  │     │     │  └─ 📄RockerOptions.ets        # 摇杆选项
│  │     │     ├─ 📁utils                       # 工具包
│  │     │     │  └─ 📄MathUtils.ets            # 数学工具
│  │     │     └─ 📄RockerComponent.ets         # 摇杆组件
│  ├─ 📄Index.ets                               # 入口文件
│  └─ 📄oh-package.json5                        # 包配置
├─ 📄.gitignore
├─ 📄build-profile.json5
├─ 📄hvigorfile.ts
├─ 📄hvigorw
├─ 📄hvigorw.bat
├─ 📄oh-package-lock.json5
├─ 📄oh-package.json5
└─ 📄readme.md
```