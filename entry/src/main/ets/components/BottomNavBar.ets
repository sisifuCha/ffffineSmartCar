/** 底部四栏导航 */
import { StyledText, TextVariant } from '../styles/Typography';

export interface NavTabItem {
  label: string;
  icon: Resource;
  activeIcon?: Resource;
}

@Component
export struct BottomNavBar {
  @Link currentIndex: number;
  tabs: NavTabItem[] = [];

  build() {
    Row() {
      ForEach(this.tabs, (tab: NavTabItem, index: number) => {
        Column({ space: '3vp' }) {
          Column() {
            Image(tab.icon)
              .width('22vp')
              .height('22vp')
              .fillColor(this.currentIndex === index ?
                $r('app.color.nav_active') : $r('app.color.nav_inactive'))
          }
          .width('40vp')
          .height('32vp')
          .justifyContent(FlexAlign.Center)
          .backgroundColor(this.currentIndex === index ?
            $r('app.color.button_select_background') : Color.Transparent)
          .borderRadius('16vp')

          StyledText({
            content: tab.label,
            variant: TextVariant.NavLabel,
            textAlign: TextAlign.Center,
            hasCustomColor: true,
            customColor: this.currentIndex === index ?
              $r('app.color.nav_active') : $r('app.color.nav_inactive')
          })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .padding({ top: '10vp', bottom: '12vp' })
        .onClick(() => {
          this.currentIndex = index;
        })
      }, (tab: NavTabItem, index: number) => `${tab.label}_${index}`)
    }
    .width('100%')
    .backgroundColor($r('app.color.nav_bar_background'))
    .border({
      width: { top: 1 },
      color: $r('app.color.card_border')
    })
    .borderRadius({ topLeft: '20vp', topRight: '20vp' })
    .shadow({
      radius: 12,
      color: '#08000000',
      offsetX: 0,
      offsetY: -3
    })
  }
}
