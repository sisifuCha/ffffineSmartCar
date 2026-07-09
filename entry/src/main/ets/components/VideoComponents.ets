import web_webview from '@ohos.web.webview'
import { carApi } from '../CarUtill/CarApi';
import { CarEncode } from '../CarUtill/CarEncode';
import { ButtonShadow } from '../styles/styles';

let TAG = "VideoComponents"

@Component
export struct VideoComponents {
  controller: web_webview.WebviewController = new web_webview.WebviewController()
  public static port: number = 6500;
  public static ip: string = "192.168.1.11"
  // 当前是否正在录制视频
  @State isRecording: boolean = false

  build() {
    Column() {
      RelativeContainer() {

        Web({
          src: this.getWebSrc(),
          controller: this.controller
        })
          .id("Video")

        // 如果正在录制，显示小红点
        if (this.isRecording)
          RedRound()
            .id("RedRound")
            .zIndex(2)
            .alignRules({
              bottom: { anchor: "__container__", align: VerticalAlign.Bottom },
              right: { anchor: "__container__", align: HorizontalAlign.End }
            }).offset({
            x: -30,
            y: -30
          })
      }

      .width('300vp')
      .height('200vp')

      Row() {
        if (this.isRecording == false) {
          // 如果不在录像，那么允许拍摄
          Button("拍摄")
            .backgroundColor($r('app.color.button_background'))
            .shadow(ButtonShadow)
            .onClick(() => {
              carApi.send(CarEncode.TakePhotosEncode());
            })
        }


        Button(this.isRecording == false ? "录制" : "结束")
          .backgroundColor($r('app.color.button_background'))
          .shadow(ButtonShadow)
          .onClick(() => {
            if (this.isRecording == true) {
              // 如果正在录制那么暂停视频
              carApi.send(CarEncode.CloselRecordingEncode());
            } else {
              // 如果不在录制那么开始录制
              carApi.send(CarEncode.StartRecordingEncode());
            }
            this.isRecording = !this.isRecording;
          })

      }
    }.justifyContent(FlexAlign.Center)

  }

  getWebSrc() {
    let v = `http://${VideoComponents.ip}:${VideoComponents.port}/index2`
    console.log(TAG, "getWebSrc()", v)
    return v

  }
}

@Component
struct RedRound {
  @State isShow: boolean = true;

  aboutToAppear(): void {
    setInterval(() => {
      // console.log('Hello, World!');
      this.isShow = !this.isShow;
    }, 1000);

  }

  build() {
    Text()
      .width('10vp')
      .height('10vp')
      .backgroundColor(Color.Red)
      .animation({
        duration: 1200,
        curve: Curve.Friction,
        delay: 500,
        iterations: -1, // 设置-1表示动画无限循环
      })
      .border({
        radius: "5vp"
      })
      .visibility(this.isShow ? Visibility.Visible : Visibility.None)
  }
}
