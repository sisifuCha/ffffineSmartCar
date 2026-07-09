/**
 * 网络设置界面
 */
import { TCPClientManager } from '../tcp/TCPClientManager'
import { TCPClientSendUtils } from '../tcp/TCPClientSendUtils'
import { DualCarStatusManager } from '../tcp/DualCarStatusManager'
import promptAction from '@ohos.promptAction'
import router from '@ohos.router'
import { PreferencesUtils } from '../utils/PreferencesUtils'
import { VideoComponents } from '../components/VideoComponents'
import { ButtonShadow } from '../styles/styles'


@Entry
@Component
struct NetworkSettings {
  build() {
    Column() {
      Row() {
        Column() {
          LoginComponent({
            connectSuccessRun: () => {
              router.pushUrl({ url: "pages/Index" })
            },
            connectfailRun: () => {
            }
          })
            .width('320vp')
        }
        .height('100%')
        .width(0)
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
      .height('100%')
    }
    .backgroundColor($r('app.color.window_background'))
  }
}

@Component
struct LoginComponent {
  TextWidth: Length = '90vp';
  FontSize: Length = '18fp'
  BlankWidth: Length = '10vp'

  @State ip: string = "192.168.1.11"
  @State tcpPort: string = "6000"
  @State videoPort: string = "6500"
  @State slaveIp: string = "192.168.1.12"
  @State slavePort: string = "6001"
  @State dualMode: boolean = false

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
    netUtils.getSlaveIp().then((v: string) => this.slaveIp = v)
    netUtils.getSlavePort().then((v: string) => this.slavePort = v)
    netUtils.getDualMode().then((v: boolean) => this.dualMode = v)
  }

  private async saveNetConfig(): Promise<void> {
    const netUtils = PreferencesUtils.getInstance().netUtils;
    await netUtils.setIp(this.ip)
    await netUtils.setTcpPort(this.tcpPort)
    await netUtils.setVideoPort(this.videoPort)
    await netUtils.setSlaveIp(this.slaveIp)
    await netUtils.setSlavePort(this.slavePort)
    await netUtils.setDualMode(this.dualMode)
  }

  build() {
    Column() {
      Row() {
        Text("主车IP:")
          .width(this.TextWidth)
          .textAlign(TextAlign.End)
          .fontSize(this.FontSize)
          .fontColor($r('app.color.button_text'))
        Blank().width(this.BlankWidth)
        TextInput({ text: this.ip })
          .onChange((v) => this.ip = v)
          .layoutWeight(1)
          .backgroundColor($r('app.color.edit_text_background'))
      }.width('100%')
      .LoginComponentLineStyle()

      Row() {
        Text("TCP:")
          .width(this.TextWidth)
          .textAlign(TextAlign.End)
          .fontSize(this.FontSize)
          .fontColor($r('app.color.button_text'))
        Blank().width(this.BlankWidth)
        TextInput({ text: this.tcpPort })
          .onChange((v) => this.tcpPort = v)
          .layoutWeight(1)
          .backgroundColor($r('app.color.edit_text_background'))
      }
      .width('100%')
      .LoginComponentLineStyle()

      Row() {
        Text("Video:")
          .width(this.TextWidth)
          .textAlign(TextAlign.End)
          .fontSize(this.FontSize)
          .fontColor($r('app.color.button_text'))
        Blank().width(this.BlankWidth)
        TextInput({ text: this.videoPort })
          .onChange((v) => this.videoPort = v)
          .layoutWeight(1)
          .backgroundColor($r('app.color.edit_text_background'))
      }.width('100%')
      .LoginComponentLineStyle()

      Row() {
        Toggle({ type: ToggleType.Switch, isOn: this.dualMode })
          .onChange((v: boolean) => this.dualMode = v)
        Text("双车模式")
          .fontSize(this.FontSize)
          .fontColor($r('app.color.button_text'))
          .margin({ left: '8vp' })
      }
      .width('100%')
      .LoginComponentLineStyle()

      if (this.dualMode) {
        Row() {
          Text("从车IP:")
            .width(this.TextWidth)
            .textAlign(TextAlign.End)
            .fontSize(this.FontSize)
            .fontColor($r('app.color.button_text'))
          Blank().width(this.BlankWidth)
          TextInput({ text: this.slaveIp })
            .onChange((v) => this.slaveIp = v)
            .layoutWeight(1)
            .backgroundColor($r('app.color.edit_text_background'))
        }.width('100%')
        .LoginComponentLineStyle()

        Row() {
          Text("从车端口:")
            .width(this.TextWidth)
            .textAlign(TextAlign.End)
            .fontSize(this.FontSize)
            .fontColor($r('app.color.button_text'))
          Blank().width(this.BlankWidth)
          TextInput({ text: this.slavePort })
            .onChange((v) => this.slavePort = v)
            .layoutWeight(1)
            .backgroundColor($r('app.color.edit_text_background'))
        }.width('100%')
        .LoginComponentLineStyle()
      }

      Button("连接").onClick(() => {
        this.saveNetConfig()
        this.initTcpConfig()
        VideoComponents.ip = this.ip;
        VideoComponents.port = Number.parseInt(this.videoPort)
      })
        .width('200vp')
        .backgroundColor($r('app.color.button_background'))
        .shadow(ButtonShadow)
        .margin({ top: '10vp' })
    }
  }

  private async initTcpConfig(): Promise<void> {
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

    TCPClientManager.getInstance().initNetAddress({
      address: this.ip,
      port: Number.parseInt(this.tcpPort)
    });
    let isConnect = await TCPClientManager.getInstance().connect();
    if (isConnect) {
      if (this.dualMode) {
        const configMsg = DualCarStatusManager.buildConfigMessage(
          true,
          this.slaveIp,
          Number.parseInt(this.slavePort)
        )
        await TCPClientManager.getInstance().sendMessage(configMsg)
      }
      promptAction.showToast({
        message: this.dualMode ? "已连接主车，双车模式已启用" : "连接成功"
      })
      TCPClientSendUtils.getInstance().init();
      this.connectSuccessRun();
    } else {
      promptAction.showToast({ message: "连接失败，请检查主车 IP 和端口" })
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

@Styles
function LoginComponentLineStyle() {
  .margin('5vp')
}
