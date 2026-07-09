import router from '@ohos.router';
import { ButtonShadow } from '../styles/styles';

@Entry
@Component
struct Index {
  @State message: string = 'Hello World';

  build() {
    Column() {
      Scroll() {
        Row({ space: '30vp' }) {
          // this.newLocalBuilder
          ItemButton({
            text: "麦科朗姆",
            icon:$r('app.media.tire'),
            event: () => {
              router.pushUrl({
                url: 'pages/MecanumWheel',
              })
            }
          })
            .width('300vp')
            .height('100%')

          ItemButton({
            text: "单独控制",
            icon:$r('app.media.vector'),
            event: () => {
              router.pushUrl({ url: 'pages/RemoteControl', })
            }
          })
            .width('300vp')
            .height('100%')
        }
        .height('60%')
      }
      .scrollable(ScrollDirection.Horizontal) // 滚动方向纵向
      .height('100%')
    }
    .width('100%')
    .backgroundColor($r('app.color.window_background'))
  }
}

@Component
struct ItemButton {
  @State text: string = "";
  @State icon: Resource = $r('app.media.app_icon');
  event: (event?: ClickEvent) => void = () => {
  }

  build() {
    Stack() {
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Column({space:"10vp"}) {
          // 图标
          Image(this.icon)
            .width('130vp')
            .height('130vp')
          // 文字
          Text(this.text)
            .fontColor($r('app.color.text'))
            .fontSize($r("app.float.index_text_size"))
        }

      }
      .width('100%')
      .height('100%')
      .onClick(() => {
        this.event()
      })
      .backgroundColor($r('app.color.button_background'))
      .shadow(ButtonShadow)
      .borderRadius($r('app.float.index_button_radius'))
    }
  }
}