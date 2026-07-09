/**
 * 麦克纳姆轮单独控制界面
 */
import { carApi } from '../CarUtill/CarApi';
import { CarEncode } from '../CarUtill/CarEncode';
import { CarRockerComponents } from '../components/CarRockerComponents';
import { DualCarStatusBar } from '../components/DualCarStatusBar';

const TAG = 'SmartCarMecanumWheel'

@Entry
@Component
struct MecanumWheel {
  @State message: string = 'Hello World';
  /**左前轮*/
  @State L1Value: number = 0;
  /**左后轮*/
  @State L2Value: number = 0;
  /**前后轮*/
  @State R1Value: number = 0;
  /**右后轮*/
  @State R2Value: number = 0;

  build() {
    Column() {
      DualCarStatusBar()
        .margin({ left: '10vp', right: '10vp', top: '8vp' })

      Row() {
      // 左侧一条
      Column() {
        // 前后轮单独控制
        Column() {
          // 左前轮
          SliderComponent({
            value: $L1Value
          })
          // 左后轮
          SliderComponent({
            value: $L2Value
          })


        }
        .width('100%')
        .height(0)
        .padding({ left: '30vp', right: '30vp' })
        .justifyContent(FlexAlign.Center)
        .layoutWeight(1)
        .myBroderStyles()

        // 遥杆
        Column() {
          CarRockerComponents()
            .width('150vp')
            .height('150vp')
        }
        .width('100%')
        .height(0)
        .layoutWeight(1)
        .myBroderStyles()
      }
      .height('100%')
      .width(0)
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .myBroderStyles()

      // 右侧一条
      Column() {
        // 前后轮单独控制
        Column() {
          // 右前轮
          SliderComponent({
            value: $R1Value
          })
          // 右后轮
          SliderComponent({
            value: $R2Value
          })
        }
        .height(0)
        .width('100%')
        .padding({ left: '30vp', right: '30vp' })
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .myBroderStyles()

        Row() {

          Button('更新速度')
            .onClick(() => {
              // 发送车辆速度
              this.sendSpeed();
            })
            .fontSize($r('app.float.float_1'))
            .backgroundColor($r('app.color.button_background'))

          Button('全部归零')
            .onClick(() => {
              this.L1Value = 0
              this.L2Value = 0
              this.R1Value = 0
              this.R2Value = 0
              // 发送车辆速度
              this.sendSpeed();
            })
            .fontSize($r('app.float.float_1'))
            .backgroundColor($r('app.color.button_background'))
        }
        .height(0)
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .myBroderStyles()
      }
      .height('100%')
      .width(0)
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .myBroderStyles()

    }
    .width('100%')
    .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .padding({
      left: '10vp',
      right: '10vp',
      top: '30vp',
      bottom: '30vp'
    })
    .backgroundColor($r('app.color.window_background'))

  }

  /**边框样式*/
  @Styles
  myBroderStyles() {
    .border({
      radius: '10vp',
      color: Color.Gray,
      width: '0vp'
    })
  }

  /**
   * 发送数据到真实的车辆
   */
  sendSpeed() {
    console.log(TAG, 'speed', `l1`, this.L1Value, 'l2', this.L2Value)
    console.log(TAG, 'speed', `l1`, this.L1Value, 'l2', this.L2Value)
    //发送速度数据
    carApi.send(CarEncode.UpSpeedCarEncode(this.L1Value, this.L2Value, this.R1Value, this.R2Value));
  }
}

/**
 * 拖动状态条组件
 */
@Component
struct SliderComponent {
  @Link value: number;

  build() {
    Row() {
      // 左前轮
      Slider({
        value: this.value,
        min: -100,
        max: 100,
        style: SliderStyle.InSet
      })
        .blockColor($r('app.color.track_select_background'))
          .trackColor($r('app.color.track_background'))
          .selectedColor($r("app.color.slider_selected"))
          // .showTips(true)
        .onChange((value: number, mode: SliderChangeMode) => {
          this.value = value
          console.info('value:' + value + 'mode:' + mode.toString())
        })
      Text(
        `${this.value.toFixed(0)}`
      )
        .width('30vp')
        .textAlign(TextAlign.Center)
        .fontColor($r('app.color.text'))
        .fontSize($r('app.float.float_1'))


    }
  }
}