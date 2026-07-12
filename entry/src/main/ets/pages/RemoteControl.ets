/**
 * 遥控界面（竖屏）
 */
import { carApi } from '../CarUtill/CarApi';
import { CarEncode } from '../CarUtill/CarEncode';
import { CarBtnComponents } from '../components/CarBtnComponents';
import { CarRockerComponents } from '../components/CarRockerComponents';
import { EmergencyStopButton } from '../components/EmergencyStopButton';
import { DualCarStatusBar } from '../components/DualCarStatusBar';
import { VideoComponents } from '../components/VideoComponents';
import { AppRadius, CardShadow } from '../styles/styles';
import { AppFont } from '../styles/Typography';

@Component
export struct RemoteControlPanel {
  @State nowCtrlModel: CtrlModel = CtrlModel.Button
  @State trackingEnabled: boolean = false
  ctrlTextTextList: string[] = ["按钮", "摇杆"]
  ctrlModeList: CtrlModel[] = [CtrlModel.Button, CtrlModel.Rocker]

  build() {
    Scroll() {
      Column({ space: '14vp' }) {
        DualCarStatusBar()

        Column({ space: '10vp' }) {
          Text('实时画面')
            .fontFamily(AppFont.FAMILY)
            .fontSize('15fp')
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text'))
            .width('100%')
          Text('来自小车摄像头的实时视频流')
            .fontFamily(AppFont.FAMILY)
            .fontSize('12fp')
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
          VideoComponents()
        }
        .width('100%')
        .padding('16vp')
        .backgroundColor($r('app.color.card_background'))
        .borderRadius(AppRadius.LG)
        .border({ width: 1, color: $r('app.color.card_border') })
        .shadow(CardShadow)

        Column({ space: '8vp' }) {
          Text('控制方式')
            .fontFamily(AppFont.FAMILY)
            .fontSize('15fp')
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text'))
            .width('100%')
          Row({ space: '8vp' }) {
            ForEach(this.ctrlTextTextList, (item: string, index: number) => {
              Text(item)
                .layoutWeight(1)
                .textAlign(TextAlign.Center)
                .fontSize('14fp')
                .fontFamily(AppFont.FAMILY)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.nowCtrlModel === this.ctrlModeList[index] ?
                  $r('app.color.button_text_on_primary') : $r('app.color.text'))
                .padding({ top: '10vp', bottom: '10vp' })
                .backgroundColor(this.nowCtrlModel === this.ctrlModeList[index] ?
                  $r('app.color.button_background') : $r('app.color.button_select_background'))
                .borderRadius(AppRadius.MD)
                .onClick(() => {
                  this.nowCtrlModel = this.ctrlModeList[index]
                })
            }, (item: string) => item)
          }
          .width('100%')
        }
        .width('100%')

        Column({ space: '8vp' }) {
          Text(this.nowCtrlModel === CtrlModel.Button ? '方向按钮控制' : '摇杆控制')
            .fontFamily(AppFont.FAMILY)
            .fontSize('13fp')
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .textAlign(TextAlign.Center)

          if (this.nowCtrlModel === CtrlModel.Button) {
            CarBtnComponents()
              .width('220vp')
              .height('220vp')
          } else {
            Column({ space: '12vp' }) {
              CarRockerComponents()
                .width('220vp')
                .height('220vp')
              EmergencyStopButton({ fullWidth: false })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
          }
        }
        .width('100%')
        .padding('20vp')
        .alignItems(HorizontalAlign.Center)
        .backgroundColor($r('app.color.card_background'))
        .borderRadius(AppRadius.LG)
        .border({ width: 1, color: $r('app.color.card_border') })
        .shadow(CardShadow)

        Column({ space: '8vp' }) {
          Text('自动循迹')
            .fontFamily(AppFont.FAMILY)
            .fontSize('15fp')
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text'))
            .width('100%')
          Row({ space: '10vp' }) {
            Checkbox({ name: 'tracking', group: 'remote' })
              .select(this.trackingEnabled)
              .onChange((value: boolean) => {
                this.trackingEnabled = value
                if (value) {
                  carApi.send(CarEncode.TrackingOpenEncode());
                } else {
                  carApi.send(CarEncode.TrackingCloseEncode());
                }
              })
            Text('开启自动循迹')
              .fontFamily(AppFont.FAMILY)
              .fontSize('15fp')
              .fontColor($r('app.color.text'))
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          Text('勾选后小车将沿地面黑线自动行驶，取消勾选停止循迹')
            .fontFamily(AppFont.FAMILY)
            .fontSize('12fp')
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
        }
        .width('100%')
        .padding('16vp')
        .backgroundColor($r('app.color.card_background'))
        .borderRadius(AppRadius.LG)
        .border({ width: 1, color: $r('app.color.card_border') })
        .shadow(CardShadow)
      }
      .width('100%')
      .padding({ left: '16vp', right: '16vp', top: '8vp', bottom: '16vp' })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .backgroundColor($r('app.color.window_background'))
  }
}

enum CtrlModel {
  Button = 0,
  Rocker = 1,
}
