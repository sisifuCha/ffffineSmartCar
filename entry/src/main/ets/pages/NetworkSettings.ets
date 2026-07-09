/**
 * 网络设置界面
 */
import { TCPClientManager } from '../tcp/TCPClientManager'
import { TCPClientSendUtils } from '../tcp/TCPClientSendUtils'
import promptAction from '@ohos.promptAction'
import router from '@ohos.router'
import { PreferencesUtils } from '../utils/PreferencesUtils'
import { VideoComponents } from '../components/VideoComponents'
import { ButtonShadow } from '../styles/styles'


@Entry
@Component
struct NetworkSettings {
  // @State message: string = 'Hello World';

  build() {
    Column() {
      // 标题
      Stack() {


      }

      // 主体
      Row() {
        Column() {
          LoginComponent({
            connectSuccessRun: () => {
              // 如果连接成功 打开主页
              router.pushUrl({ url: "pages/Index" })
            },
            connectfailRun: () => {
            }
          })
            .width('300vp')

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
  // 控件大小
  TextWidth: Length = '80vp';
  FontSize: Length = '20fp'
  BlankWidth: Length = '10vp'
  //
  @State ip: string = "192.168.1.11"
  @State tcpPort: string = "6000"
  @State videoPort: string = "6500"
  /**
   * 连接成功运行
   */
  connectSuccessRun = () => {
  }
  /**
   * 连接失败运行
   */
  connectfailRun = () => {
  }

  /**
   * 数据初始化
   */
  aboutToAppear(): void {
    this.readNetConfig();
  }

  private readNetConfig(): void {
    const netUtils = PreferencesUtils.getInstance().netUtils;
    netUtils.getIP().then((v: string) => this.ip = v)
    netUtils.getTcpPort().then((v: string) => this.tcpPort = v)
    netUtils.getVideoPort().then((v: string) => this.videoPort = v)
  }

  private async saveNetConfig(): Promise<void> {
    const netUtils = PreferencesUtils.getInstance().netUtils;
    await netUtils.setIp(this.ip)
    await netUtils.setTcpPort(this.tcpPort)
    await netUtils.setVideoPort(this.videoPort)
  }

  build() {
    Column() {
      // IP配置
      Row() {
        Text("IP:")
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

      // 端口号
      Row() {
        Text("Port:")
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

      // 视频
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

      Button("连接").onClick(() => {

        // 保存网络配置
        this.saveNetConfig()
        // 初始化TCP网络配置
        this.initTcpConfig()

        // 初始化视频网络配置
        VideoComponents.ip = this.ip;
        VideoComponents.port = Number.parseInt(this.videoPort)

      })
        .width('200vp')
        .backgroundColor($r('app.color.button_background'))
        .shadow(ButtonShadow)
    }
  }

  /**
   * 连接网络
   */
  private async initTcpConfig(): Promise<void> {
    if (!this.isValidIp(this.ip)) {
      promptAction.showToast({ message: "IP 地址格式不正确" })
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

    TCPClientManager.getInstance().initNetAddress({
      address: this.ip,
      port: Number.parseInt(this.tcpPort)
    });
    let isConnect = await TCPClientManager.getInstance().connect();
    if (isConnect) {
      promptAction.showToast({ message: "连接成功" })
      TCPClientSendUtils.getInstance().init();
      this.connectSuccessRun();
    } else {
      promptAction.showToast({ message: "连接失败，请检查 IP 和端口" })
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

/**
 * 行样式
 */
@Styles
function LoginComponentLineStyle() {
  .margin('5vp')
}