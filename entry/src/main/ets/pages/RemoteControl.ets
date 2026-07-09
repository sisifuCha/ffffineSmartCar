/**
 * 遥控界面
 */
import { carApi } from '../CarUtill/CarApi';
import { CarEncode } from '../CarUtill/CarEncode';
import { CarDirection } from '../CarUtill/CarEnum';
import { CarBtnComponents } from '../components/CarBtnComponents';
import { CarRockerComponents } from '../components/CarRockerComponents';
import { VideoComponents } from '../components/VideoComponents';

@Entry
@Component
struct RemoteControl {
  @State message: string = 'Hello World';
  /**当前控制模式*/
  @State nowCtrlModel: CtrlModel = CtrlModel.Button
  /**控制文本列表*/
  ctrlTextTextList: string[] = ["按钮", "遥杆"]
  /**控制模式列表*/
  ctrlModeList: CtrlModel[] = [CtrlModel.Button, CtrlModel.Rocker]

  build() {
    Row() {
      RelativeContainer() {
        Column() {
          ForEach(this.ctrlTextTextList, (item: string, index: number) => {
            MyTab({
              // 如果当前控制模式为为当前组件所属的控制模式，那么状态选中
              state: this.nowCtrlModel == this.ctrlModeList[index],
              text: item
            }).onClick(() => {
              // 当受到点击时将当前控制模式置为当前组件所属的控制模式
              state: this.nowCtrlModel = this.ctrlModeList[index]
            })

          }, (item: string) => item)
        }
        .id("tabs")
        .alignRules({
          left: { anchor: "__container__", align: HorizontalAlign.Start },
          center: { anchor: "__container__", align: VerticalAlign.Center }
        })

        Stack() {

          // 操控按钮
          CarBtnComponents()
            .border({ width: 1, color: Color.Black })
            .visibility(//如果选中控制模式为当前组件的控制模式，那么显示
              this.nowCtrlModel == CtrlModel.Button ?
              Visibility.Visible :
              Visibility.None)


          // 遥感控制
          CarRockerComponents()// .width('210vp')
            // .height('210vp')
            .border({ width: 1, color: Color.Black })
            .visibility(//如果选中控制模式为当前组件的控制模式，那么显示
              this.nowCtrlModel == CtrlModel.Rocker ?
              Visibility.Visible :
              Visibility.None)
        }
        .width('210vp')
        .height('210vp')
        .id("ctrl")
        .alignRules({
          center: { anchor: "__container__", align: VerticalAlign.Center },
          middle: { anchor: "__container__", align: HorizontalAlign.Center }
        })

      }
      .width(0)
      .layoutWeight(1)
      .height('100%')

      Column() {
        // 视频播放组件
        VideoComponents()
        Row() {
          Checkbox() {
            Text("自动循迹")
          }.onChange((value: boolean) => {
            if (value) {
              carApi.send(CarEncode.TrackingOpenEncode());
            } else {
              carApi.send(CarEncode.TrackingCloseEncode());
            }
          })
        }
      }
      .width(0)
      .height('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    }
    .height('100%')
    .backgroundColor($r('app.color.window_background'))
  }
}

enum CtrlModel {
  Button = 0,
  Rocker = 1,
}

// 标签
@Component
struct MyTab {
  @Prop state: boolean = false;
  @Prop text: string = "hello";
  /**选中颜色*/
  trueColor: string|Resource = $r('app.color.button_select_background')
  /**未被选中颜色*/
  falseColor: string|Resource = $r('app.color.button_background')

  build() {
    Stack() {
      Text(this.text)
        .width('20vp')
        .fontSize('20fp')
    }
    .backgroundColor(this.state ? this.trueColor : this.falseColor)
    .border({
      radius: {
        topRight: '15vp',
        bottomRight: '15vp'
      }
    })
    .padding({
      left: '15vp',
      right: '15vp',
      top: '10vp',
      bottom: '10vp',
    })
  }
}