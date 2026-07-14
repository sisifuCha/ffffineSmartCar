import web_webview from '@ohos.web.webview'
import { carApi } from '../CarUtill/CarApi';
import { CarEncode } from '../CarUtill/CarEncode';
import { AppSession } from '../model/AppSession';
import { AppRadius, ButtonShadow } from '../styles/styles';
import { AppFont, StyledText, TextVariant } from '../styles/Typography';
import { PreferencesUtils } from '../utils/PreferencesUtils';

let TAG = "VideoComponents"

@Component
export struct VideoComponents {
  controller: web_webview.WebviewController = new web_webview.WebviewController()
  public static port: number = 6500;
  public static ip: string = "192.168.1.11"
  @State isRecording: boolean = false
  @State videoSrc: string = ''
  @State loadFailed: boolean = false
  @State detectVideo: boolean = true
  @StorageLink(AppSession.KEY_TCP_CONNECTED) @Watch('onConnectChange') tcpConnected: boolean = false

  aboutToAppear(): void {
    this.syncVideoConfig();
  }

  onConnectChange(): void {
    if (this.tcpConnected) {
      this.loadFailed = false;
      this.syncVideoConfig();
    } else {
      this.videoSrc = '';
      this.loadFailed = false;
    }
  }

  private async syncVideoConfig(): Promise<void> {
    if (!this.tcpConnected) {
      this.videoSrc = '';
      return;
    }
    const net = PreferencesUtils.getInstance().netUtils;
    VideoComponents.ip = await net.getIP();
    VideoComponents.port = Number.parseInt(await net.getVideoPort());
    this.detectVideo = await net.getDetectVideoEnabled();
    this.videoSrc = this.buildVideoSrc();
  }

  private shouldShowWeb(): boolean {
    return this.tcpConnected && !this.loadFailed && this.videoSrc.length > 0;
  }

  build() {
    Column({ space: '12vp' }) {
      Stack({ alignContent: Alignment.Center }) {
        if (this.shouldShowWeb()) {
          Web({
            src: this.videoSrc,
            controller: this.controller
          })
            .width('100%')
            .aspectRatio(16 / 9)
            .borderRadius(AppRadius.MD)
            .clip(true)
            .backgroundColor('#EEEDEA')
            .onErrorReceive(() => {
              this.loadFailed = true;
            })
            .onHttpErrorReceive(() => {
              this.loadFailed = true;
            })
        } else {
          Column({ space: '6vp' }) {
            StyledText({
              content: this.tcpConnected && this.loadFailed ? '视频加载失败' : '暂无画面',
              variant: TextVariant.Body,
              textAlign: TextAlign.Center,
              hasCustomColor: true,
              customColor: $r('app.color.text_secondary')
            })
            StyledText({
              content: this.tcpConnected ?
                (this.detectVideo ?
                  `请先在 Jetson 启动检测：bash ~/temp/vision/start_detect_preview.sh（端口 ${VideoComponents.port}）` :
                  '请确认摄像头服务已开启（视频端口 6500）') :
                '连接小车后将显示实时画面',
              variant: TextVariant.Caption,
              textAlign: TextAlign.Center
            })
          }
          .width('100%')
          .aspectRatio(16 / 9)
          .justifyContent(FlexAlign.Center)
          .borderRadius(AppRadius.MD)
          .backgroundColor('#EEEDEA')
        }

        if (this.isRecording && this.shouldShowWeb()) {
          RedRound()
            .margin({ right: '12vp', bottom: '12vp' })
        }
      }
      .width('100%')
      .alignContent(Alignment.BottomEnd)

      Row({ space: '10vp' }) {
        if (!this.isRecording) {
          Button('拍摄')
            .layoutWeight(1)
            .height('40vp')
            .fontSize('14fp')
            .fontFamily(AppFont.FAMILY)
            .fontColor($r('app.color.button_text_on_primary'))
            .backgroundColor($r('app.color.button_background'))
            .borderRadius(AppRadius.SM)
            .shadow(ButtonShadow)
            .onClick(() => {
              carApi.send(CarEncode.TakePhotosEncode());
            })
        }

        Button(this.isRecording ? '结束' : '录制')
          .layoutWeight(1)
          .height('40vp')
          .fontSize('14fp')
          .fontFamily(AppFont.FAMILY)
          .fontColor($r('app.color.button_text_on_primary'))
          .backgroundColor($r('app.color.button_background'))
          .borderRadius(AppRadius.SM)
          .shadow(ButtonShadow)
          .onClick(() => {
            if (this.isRecording) {
              carApi.send(CarEncode.CloselRecordingEncode());
            } else {
              carApi.send(CarEncode.StartRecordingEncode());
            }
            this.isRecording = !this.isRecording;
          })
      }
      .width('100%')
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  private buildVideoSrc(): string {
    const v = this.detectVideo ?
      `http://${VideoComponents.ip}:${VideoComponents.port}/` :
      `http://${VideoComponents.ip}:${VideoComponents.port}/index2`;
    console.log(TAG, "buildVideoSrc()", v)
    return v
  }
}

@Component
struct RedRound {
  @State isShow: boolean = true;

  aboutToAppear(): void {
    setInterval(() => {
      this.isShow = !this.isShow;
    }, 1000);
  }

  build() {
    Text()
      .width('10vp')
      .height('10vp')
      .backgroundColor('#C9A89A')
      .borderRadius('5vp')
      .visibility(this.isShow ? Visibility.Visible : Visibility.None)
  }
}
