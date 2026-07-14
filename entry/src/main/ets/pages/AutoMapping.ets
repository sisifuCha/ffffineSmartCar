/**
 * 自动建图 / 自动定位控制页（TCP 6002，# 后 8 位命令）
 * 检测画面：Jetson 上 object_detect --preview 8090 后，本页 WebView 显示
 */
import web_webview from '@ohos.web.webview';
import { CarEncode } from '../CarUtill/CarEncode';
import { MappingTCPClient } from '../tcp/MappingTCPClient';
import { PreferencesUtils } from '../utils/PreferencesUtils';
import { ButtonShadow } from '../styles/styles';
import promptAction from '@ohos.promptAction';

enum MappingState {
  Idle = '空闲',
  Mapping = '自动建图中',
  Localizing = '自动定位中'
}

@Entry
@Component
struct AutoMapping {
  detectPreviewPort: number = 8090
  controller: web_webview.WebviewController = new web_webview.WebviewController()
  @State statusText: string = MappingState.Idle
  @State tipText: string = 'Jetson 先运行 nav_with_detect.sh，再点「开始自动定位」'
  @State connected: boolean = false
  @State jetsonIp: string = '192.168.1.11'
  @State detectPreviewUrl: string = ''

  aboutToAppear(): void {
    PreferencesUtils.getInstance().netUtils.getIP().then((ip: string) => {
      this.jetsonIp = ip;
      this.detectPreviewUrl = `http://${ip}:${this.detectPreviewPort}/`;
    });
    MappingTCPClient.getInstance().connectFromPrefs().then((ok: boolean) => {
      this.connected = ok;
      if (!ok) {
        this.tipText = '建图端口 6002 未连接，请确认 Jetson 已启动 tcp_server_6002'
      }
    });
  }

  private async sendMappingCmd(message: string, onOk: () => void): Promise<void> {
    const ok = await MappingTCPClient.getInstance().send(message);
    if (ok) {
      onOk();
    } else {
      promptAction.showToast({ message: '命令发送失败' });
    }
  }

  build() {
    Column({ space: '20vp' }) {
      Text('自动建图 / 定位')
        .fontSize('24fp')
        .fontColor($r('app.color.text'))

      Text(`状态：${this.statusText}`)
        .fontSize('18fp')
        .fontColor($r('app.color.text'))

      Text(this.tipText)
        .fontSize('14fp')
        .fontColor($r('app.color.text'))
        .width('80%')
        .textAlign(TextAlign.Center)

      Text(this.connected ? '建图端口：已连接 6002' : '建图端口：未连接')
        .fontSize('12fp')
        .fontColor($r('app.color.text'))

      Row({ space: '20vp' }) {
        Button('开始自动建图')
          .backgroundColor($r('app.color.button_background'))
          .shadow(ButtonShadow)
          .onClick(() => {
            this.sendMappingCmd(CarEncode.StartAutoMappingEncode(), () => {
              this.statusText = MappingState.Mapping
              this.tipText = '小车将自主探索并建图，完成后请点「停止并保存」'
            })
          })

        Button('停止并保存')
          .backgroundColor($r('app.color.button_background'))
          .shadow(ButtonShadow)
          .onClick(() => {
            this.sendMappingCmd(CarEncode.StopAutoMappingEncode(), () => {
              this.statusText = MappingState.Idle
              this.tipText = '地图已请求保存，可在小车 ROS 端查看 maps 目录'
            })
          })
      }

      Row({ space: '20vp' }) {
        Button('开始自动定位')
          .backgroundColor($r('app.color.button_background'))
          .shadow(ButtonShadow)
          .onClick(() => {
            this.sendMappingCmd(CarEncode.StartAutoLocalizationEncode(), () => {
              this.statusText = MappingState.Localizing
              this.tipText = '寻路中；下方为检测画面（水瓶/人/书等识别框+语音）'
            })
          })

        Button('停止定位')
          .backgroundColor($r('app.color.button_background'))
          .shadow(ButtonShadow)
          .onClick(() => {
            this.sendMappingCmd(CarEncode.StopAutoLocalizationEncode(), () => {
              this.statusText = MappingState.Idle
              this.tipText = '定位已停止'
            })
          })
      }

      Text('检测画面（寻路+识别）')
        .fontSize('14fp')
        .fontColor($r('app.color.text'))
        .margin({ top: '8vp' })

      if (this.detectPreviewUrl.length > 0) {
        Web({
          src: this.detectPreviewUrl,
          controller: this.controller
        })
          .width('90%')
          .height('220vp')
          .backgroundColor('#111111')
      } else {
        Text('未配置 Jetson IP，请到网络设置填写')
          .fontSize('12fp')
          .fontColor($r('app.color.text'))
      }

      Text(`预览地址: http://${this.jetsonIp}:${this.detectPreviewPort}/`)
        .fontSize('11fp')
        .fontColor($r('app.color.text'))
        .opacity(0.7)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.window_background'))
  }
}
