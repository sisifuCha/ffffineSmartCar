/**
 * 网络设置界面（竖屏 · 卡片式）
 */
import { TCPClientManager, TcpConnectResult } from '../tcp/TCPClientManager'
import { TCPClientSendUtils } from '../tcp/TCPClientSendUtils'
import { DualCarStatusManager } from '../tcp/DualCarStatusManager'
import promptAction from '@ohos.promptAction'
import router from '@ohos.router'
import { AppSession } from '../model/AppSession'
import { PreferencesUtils } from '../utils/PreferencesUtils'
import { VideoComponents } from '../components/VideoComponents'
import { AppRadius, ButtonShadow, CardShadow } from '../styles/styles'
import { AppFont, StyledText, TextVariant } from '../styles/Typography'
import { ScreenUtils } from '../utils/ScreenUtils'


@Entry
@Component
struct NetworkSettings {
  @StorageProp(ScreenUtils.SAFE_AREA_TOP_KEY) safeAreaTopPx: number = 36;

  build() {
    Scroll() {
      Column() {
        LoginComponent({
          connectSuccessRun: () => {
            router.replaceUrl({ url: "pages/Main" })
          },
          connectfailRun: () => {
          }
        })
      }
      .width('100%')
      .padding({
        left: '20vp',
        right: '20vp',
        top: `${Math.max(this.safeAreaTopPx, 36) + 16}px`,
        bottom: '32vp'
      })
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .backgroundColor($r('app.color.window_background'))
  }
}

@Component
struct LoginComponent {
  @State ip: string = "192.168.1.11"
  @State tcpPort: string = "6000"
  @State videoPort: string = "6500"
  @State sensorPort: string = "5001"
  @State detectVideo: boolean = true
  @State slaveIp: string = "192.168.1.12"
  @State slavePort: string = "6001"
  @State dualMode: boolean = false
  @State connecting: boolean = false
  @State lastConnectError: string = ''

  connectSuccessRun = () => {
  }
  connectfailRun = () => {
  }

  aboutToAppear(): void {
    this.readNetConfig();
  }

  private readNetConfig(): void {
    const netUtils = PreferencesUtils.getInstance().netUtils;
    netUtils.getIP().then((v: string) => this.ip = v)
    netUtils.getTcpPort().then((v: string) => this.tcpPort = v)
    netUtils.getVideoPort().then((v: string) => this.videoPort = v)
    netUtils.getSensorPort().then((v: string) => this.sensorPort = v)
    netUtils.getDetectVideoEnabled().then((v: boolean) => {
      this.detectVideo = v
      if (v && this.videoPort === '6500') {
        this.videoPort = '8090'
      }
    })
    netUtils.getSlaveIp().then((v: string) => this.slaveIp = v)
    netUtils.getSlavePort().then((v: string) => this.slavePort = v)
    netUtils.getDualMode().then((v: boolean) => this.dualMode = v)
  }

  private async saveNetConfig(): Promise<void> {
    const netUtils = PreferencesUtils.getInstance().netUtils;
    await netUtils.setIp(this.ip)
    await netUtils.setTcpPort(this.tcpPort)
    await netUtils.setVideoPort(this.videoPort)
    await netUtils.setSensorPort(this.sensorPort)
    await netUtils.setDetectVideoEnabled(this.detectVideo)
    await netUtils.setSlaveIp(this.slaveIp)
    await netUtils.setSlavePort(this.slavePort)
    await netUtils.setDualMode(this.dualMode)
  }

  build() {
    Column({ space: '20vp' }) {
      Column({ space: '6vp' }) {
        StyledText({ content: '智能小车', variant: TextVariant.Title, textAlign: TextAlign.Center })
        StyledText({
          content: '连接小车 IP 后即可操控',
          variant: TextVariant.Subtitle,
          textAlign: TextAlign.Center
        })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      Column({ space: '14vp' }) {
        Column({ space: '4vp' }) {
          Text('网络配置')
            .fontFamily(AppFont.FAMILY)
            .fontSize('16fp')
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text'))
            .width('100%')
          Text('请输入正确的 IP，并与小车处于同一 WiFi')
            .fontFamily(AppFont.FAMILY)
            .fontSize('12fp')
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
        }

        SettingField({
          label: '主车 IP',
          hint: '小车 WiFi 地址，如 192.168.1.11',
          value: this.ip,
          onChange: (v: string) => this.ip = v
        })
        SettingField({
          label: 'TCP 端口',
          hint: '控制指令端口，默认 6000',
          value: this.tcpPort,
          onChange: (v: string) => this.tcpPort = v
        })
        SettingField({
          label: this.detectVideo ? '检测画面端口' : '视频端口',
          hint: this.detectVideo ? 'YOLO 检测预览，默认 8090（需 Jetson 运行 start_detect_preview.sh）' : '摄像头画面端口，默认 6500',
          value: this.videoPort,
          onChange: (v: string) => this.videoPort = v
        })
        SettingField({
          label: '传感器端口',
          hint: 'HTTP 传感器数据端口，默认 5001（JSON 键值对）',
          value: this.sensorPort,
          onChange: (v: string) => this.sensorPort = v
        })

        Row({ space: '10vp' }) {
          Toggle({ type: ToggleType.Switch, isOn: this.detectVideo })
            .onChange((v: boolean) => {
              this.detectVideo = v
              if (v && this.videoPort === '6500') {
                this.videoPort = '8090'
              } else if (!v && this.videoPort === '8090') {
                this.videoPort = '6500'
              }
            })
          Text('AI 检测画面（水瓶/人等识别框）')
            .fontFamily(AppFont.FAMILY)
            .fontSize('15fp')
            .fontColor($r('app.color.text'))
        }
        .width('100%')
        .padding({ left: '4vp' })

        Row({ space: '10vp' }) {
          Toggle({ type: ToggleType.Switch, isOn: this.dualMode })
            .onChange((v: boolean) => this.dualMode = v)
          Text('双车模式（主车 + 从车同步）')
            .fontFamily(AppFont.FAMILY)
            .fontSize('15fp')
            .fontColor($r('app.color.text'))
        }
        .width('100%')
        .padding({ left: '4vp' })

        if (this.dualMode) {
          SettingField({
            label: '从车 IP',
            hint: '第二辆小车的 IP 地址',
            value: this.slaveIp,
            onChange: (v: string) => this.slaveIp = v
          })
          SettingField({
            label: '从车端口',
            hint: '从车 TCP 端口，默认 6001',
            value: this.slavePort,
            onChange: (v: string) => this.slavePort = v
          })
        }
      }
      .width('100%')
      .padding('20vp')
      .backgroundColor($r('app.color.card_background'))
      .borderRadius(AppRadius.LG)
      .border({ width: 1, color: $r('app.color.card_border') })
      .shadow(CardShadow)

      Button(this.connecting ? '正在连接…' : '连接小车')
        .width('100%')
        .height('48vp')
        .fontSize('16fp')
        .fontFamily(AppFont.FAMILY)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.button_text_on_primary'))
        .backgroundColor($r('app.color.button_background'))
        .borderRadius(AppRadius.MD)
        .shadow(ButtonShadow)
        .enabled(!this.connecting)
        .opacity(this.connecting ? 0.7 : 1)
        .onClick(() => {
          this.lastConnectError = ''
          this.saveNetConfig()
          this.initTcpConfig()
          VideoComponents.ip = this.ip;
          VideoComponents.port = Number.parseInt(this.videoPort)
        })

      if (this.lastConnectError.length > 0) {
        Column({ space: '6vp' }) {
          Text('连接失败')
            .fontFamily(AppFont.FAMILY)
            .fontSize('14fp')
            .fontWeight(FontWeight.Medium)
            .fontColor('#B07060')
            .width('100%')
          Text(this.lastConnectError)
            .fontFamily(AppFont.FAMILY)
            .fontSize('12fp')
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .lineHeight('18fp')
        }
        .width('100%')
        .padding('14vp')
        .backgroundColor('#F5EFEB')
        .borderRadius(AppRadius.MD)
        .border({ width: 1, color: '#E8D8D0' })
      }

      Text('我就看看')
        .fontFamily(AppFont.FAMILY)
        .fontSize('14fp')
        .fontWeight(FontWeight.Normal)
        .letterSpacing(0.3)
        .fontColor($r('app.color.text_secondary'))
        .decoration({ type: TextDecorationType.Underline, color: $r('app.color.text_secondary') })
        .onClick(() => {
          this.enterPreviewMode()
        })
    }
    .width('100%')
  }

  private async enterPreviewMode(): Promise<void> {
    await this.saveNetConfig()
    VideoComponents.ip = this.ip
    VideoComponents.port = Number.parseInt(this.videoPort)
    AppSession.enterViewOnly()
    router.replaceUrl({ url: 'pages/Main' })
  }

  private showConnectFailure(result: TcpConnectResult): void {
    this.lastConnectError = result.getDetailMessage();
    promptAction.showToast({ message: result.getShortMessage(), duration: 4000 });
  }

  private async initTcpConfig(): Promise<void> {
    if (this.connecting) {
      return;
    }
    if (!this.isValidIp(this.ip)) {
      promptAction.showToast({ message: "主车 IP 地址格式不正确" })
      return;
    }
    if (!this.isValidPort(this.tcpPort)) {
      promptAction.showToast({ message: "TCP 端口号不正确" })
      return;
    }
    if (!this.isValidPort(this.videoPort)) {
      promptAction.showToast({ message: "视频端口号不正确" })
      return;
    }
    if (this.dualMode) {
      if (!this.isValidIp(this.slaveIp)) {
        promptAction.showToast({ message: "从车 IP 地址格式不正确" })
        return;
      }
      if (!this.isValidPort(this.slavePort)) {
        promptAction.showToast({ message: "从车端口号不正确" })
        return;
      }
    }

    DualCarStatusManager.dualModeEnabled = this.dualMode
    DualCarStatusManager.reset()

    this.connecting = true;
    let connectResult: TcpConnectResult = new TcpConnectResult();
    try {
      TCPClientManager.getInstance().initNetAddress({
        address: this.ip.trim(),
        port: Number.parseInt(this.tcpPort)
      });
      connectResult = await TCPClientManager.getInstance().connect();
    } finally {
      this.connecting = false;
    }

    if (connectResult.success) {
      this.lastConnectError = ''
      AppSession.enterConnected()
      if (this.dualMode) {
        const configMsg = DualCarStatusManager.buildConfigMessage(
          true,
          this.slaveIp,
          Number.parseInt(this.slavePort)
        )
        await TCPClientManager.getInstance().sendMessage(configMsg)
      }
      promptAction.showToast({
        message: this.dualMode ? "已连接主车，双车模式已启用" : `连接成功 ${this.ip}:${this.tcpPort}`
      })
      TCPClientSendUtils.getInstance().init();
      this.connectSuccessRun();
    } else {
      AppSession.markDisconnected()
      this.showConnectFailure(connectResult);
      this.connectfailRun();
    }
  }

  private isValidIp(ip: string): boolean {
    const parts = ip.trim().split('.');
    if (parts.length !== 4) {
      return false;
    }
    for (let i = 0; i < parts.length; i++) {
      const part = parts[i];
      if (part.length === 0 || !/^\d+$/.test(part)) {
        return false;
      }
      const num = Number.parseInt(part);
      if (num < 0 || num > 255) {
        return false;
      }
    }
    return true;
  }

  private isValidPort(port: string): boolean {
    const value = port.trim();
    if (value.length === 0 || !/^\d+$/.test(value)) {
      return false;
    }
    const num = Number.parseInt(value);
    return num >= 1 && num <= 65535;
  }
}

@Component
struct SettingField {
  @Prop label: string = '';
  @Prop hint: string = '';
  @Prop value: string = '';
  onChange: (value: string) => void = () => {
  };

  build() {
    Column({ space: '6vp' }) {
      Row() {
        Text(this.label)
          .width('88vp')
          .fontFamily(AppFont.FAMILY)
          .fontSize('15fp')
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text'))
        TextInput({ text: this.value, placeholder: this.hint })
          .layoutWeight(1)
          .height('44vp')
          .fontSize('15fp')
          .fontFamily(AppFont.FAMILY)
          .placeholderColor($r('app.color.text_secondary'))
          .backgroundColor($r('app.color.edit_text_background'))
          .borderRadius(AppRadius.SM)
          .padding({ left: '14vp', right: '14vp' })
          .onChange((v: string) => this.onChange(v))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
