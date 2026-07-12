/**
 * 麦克纳姆轮控制（竖屏）
 */
import { carApi } from '../CarUtill/CarApi';
import { CarEncode } from '../CarUtill/CarEncode';
import { CarRockerComponents } from '../components/CarRockerComponents';
import { EmergencyStopButton } from '../components/EmergencyStopButton';
import { DualCarStatusBar } from '../components/DualCarStatusBar';
import { AppRadius, ButtonShadow, CardShadow } from '../styles/styles';
import { AppFont } from '../styles/Typography';

const TAG = 'SmartCarMecanumWheel'

@Component
export struct MecanumWheelPanel {
  @State L1Value: number = 0;
  @State L2Value: number = 0;
  @State R1Value: number = 0;
  @State R2Value: number = 0;

  build() {
    Scroll() {
      Column({ space: '14vp' }) {
        DualCarStatusBar()

        Column({ space: '12vp' }) {
          Text('摇杆控制')
            .fontFamily(AppFont.FAMILY)
            .fontSize('15fp')
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text'))
            .width('100%')
          Text('拖动摇杆控制小车前进、后退、转向')
            .fontFamily(AppFont.FAMILY)
            .fontSize('12fp')
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
          CarRockerComponents()
            .width('150vp')
            .height('150vp')
        }
        .width('100%')
        .padding('20vp')
        .alignItems(HorizontalAlign.Center)
        .backgroundColor($r('app.color.card_background'))
        .borderRadius(AppRadius.LG)
        .border({ width: 1, color: $r('app.color.card_border') })
        .shadow(CardShadow)

        Column({ space: '10vp' }) {
          Text('安全控制')
            .fontFamily(AppFont.FAMILY)
            .fontSize('15fp')
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text'))
            .width('100%')
          Text('紧急情况下立即停止小车所有运动')
            .fontFamily(AppFont.FAMILY)
            .fontSize('12fp')
            .fontColor($r('app.color.text_secondary'))
            .width('100%')

          EmergencyStopButton({
            fullWidth: true,
            onStopped: () => {
              this.L1Value = 0;
              this.L2Value = 0;
              this.R1Value = 0;
              this.R2Value = 0;
            }
          })
        }
        .width('100%')
        .padding('20vp')
        .alignItems(HorizontalAlign.Center)
        .backgroundColor($r('app.color.card_background'))
        .borderRadius(AppRadius.LG)
        .border({ width: 1, color: $r('app.color.card_border') })
        .shadow(CardShadow)

        Column({ space: '12vp' }) {
          Text('四轮独立调速')
            .fontFamily(AppFont.FAMILY)
            .fontSize('15fp')
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text'))
            .width('100%')
          Text('拖动滑块分别设置四个麦克纳姆轮速度（-100 ~ 100），点「应用到小车」下发')
            .fontFamily(AppFont.FAMILY)
            .fontSize('12fp')
            .fontColor($r('app.color.text_secondary'))
            .width('100%')

          SliderComponent({ label: '左前 L1', value: $L1Value })
          SliderComponent({ label: '左后 L2', value: $L2Value })
          SliderComponent({ label: '右前 R1', value: $R1Value })
          SliderComponent({ label: '右后 R2', value: $R2Value })
        }
        .width('100%')
        .padding('20vp')
        .backgroundColor($r('app.color.card_background'))
        .borderRadius(AppRadius.LG)
        .border({ width: 1, color: $r('app.color.card_border') })
        .shadow(CardShadow)

        Row({ space: '12vp' }) {
          Button('应用到小车')
            .layoutWeight(1)
            .height('44vp')
            .fontSize('15fp')
            .fontFamily(AppFont.FAMILY)
            .fontColor($r('app.color.button_text_on_primary'))
            .backgroundColor($r('app.color.button_background'))
            .borderRadius(AppRadius.MD)
            .shadow(ButtonShadow)
            .onClick(() => this.sendSpeed())

          Button('全部归零')
            .layoutWeight(1)
            .height('44vp')
            .fontSize('15fp')
            .fontFamily(AppFont.FAMILY)
            .fontColor($r('app.color.text'))
            .backgroundColor($r('app.color.button_select_background'))
            .borderRadius(AppRadius.MD)
            .onClick(() => {
              this.L1Value = 0
              this.L2Value = 0
              this.R1Value = 0
              this.R2Value = 0
              this.sendSpeed();
            })
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: '16vp', right: '16vp', top: '8vp', bottom: '16vp' })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .backgroundColor($r('app.color.window_background'))
  }

  sendSpeed() {
    console.log(TAG, 'speed', `l1`, this.L1Value, 'l2', this.L2Value)
    carApi.send(CarEncode.UpSpeedCarEncode(this.L1Value, this.L2Value, this.R1Value, this.R2Value));
  }
}

@Component
struct SliderComponent {
  @Prop label: string = '';
  @Link value: number;

  build() {
    Column({ space: '6vp' }) {
      Row() {
        Text(this.label)
          .fontFamily(AppFont.FAMILY)
          .fontSize('14fp')
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text'))
        Blank()
        Text(`${this.value.toFixed(0)}`)
          .fontFamily(AppFont.FAMILY_EN)
          .fontSize('12fp')
          .fontColor($r('app.color.text_secondary'))
          .width('36vp')
          .textAlign(TextAlign.End)
      }
      .width('100%')

      Slider({
        value: this.value,
        min: -100,
        max: 100,
        style: SliderStyle.InSet
      })
        .blockColor($r('app.color.track_select_background'))
        .trackColor($r('app.color.track_background'))
        .selectedColor($r('app.color.slider_selected'))
        .onChange((val: number) => {
          this.value = val
        })
    }
    .width('100%')
  }
}
