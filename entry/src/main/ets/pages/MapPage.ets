/**
 * 地图页：地图展示与定位/导航入口（功能预留，暂不连接定位服务）
 */
import promptAction from '@ohos.promptAction';
import { AppSession } from '../model/AppSession';
import { ButtonShadow, AppRadius, CardShadow } from '../styles/styles';
import { AppFont, StyledText, TextVariant } from '../styles/Typography';
import { PreferencesUtils } from '../utils/PreferencesUtils';

@Component
export struct MapPanel {
  @State statusText: string = '地图功能预留中';
  @State showNavPath: boolean = false;
  @StorageLink(AppSession.KEY_VIEW_ONLY) viewOnly: boolean = false;
  @StorageLink(AppSession.KEY_TCP_CONNECTED) tcpConnected: boolean = false;

  private carIp: string = '192.168.1.11';

  aboutToAppear(): void {
    this.loadConfig();
  }

  private async loadConfig(): Promise<void> {
    const net = PreferencesUtils.getInstance().netUtils;
    this.carIp = await net.getIP();
    if (this.viewOnly && !this.tcpConnected) {
      this.statusText = '浏览模式 · 连接后可使用地图功能';
      return;
    }
    if (this.tcpConnected) {
      this.statusText = '已连接 · 地图与定位功能预留中';
    } else {
      this.statusText = '未连接小车';
    }
  }

  private startLocalize(): void {
    if (this.viewOnly) {
      promptAction.showToast({ message: '浏览模式无法发起定位' });
      return;
    }
    if (!this.tcpConnected) {
      promptAction.showToast({ message: '请先连接小车' });
      return;
    }
    promptAction.showToast({ message: '自动定位功能预留中' });
  }

  build() {
    Column({ space: '12vp' }) {
      Column({ space: '12vp' }) {
        StyledText({
          content: this.statusText,
          variant: TextVariant.Status,
          textAlign: TextAlign.Center
        })
      }
      .width('100%')
      .padding({ left: '16vp', right: '16vp', top: '4vp' })

      Column({ space: '8vp' }) {
        StyledText({
          content: '暂无地图',
          variant: TextVariant.Body,
          textAlign: TextAlign.Center,
          hasCustomColor: true,
          customColor: $r('app.color.text_secondary')
        })
        StyledText({
          content: `地图服务预留 · 小车 IP：${this.carIp}`,
          variant: TextVariant.Caption,
          textAlign: TextAlign.Center
        })
      }
      .width('100%')
      .layoutWeight(1)
      .margin({ left: '16vp', right: '16vp' })
      .justifyContent(FlexAlign.Center)
      .borderRadius(AppRadius.LG)
      .clip(true)
      .border({ width: 1, color: $r('app.color.card_border') })
      .backgroundColor('#EEEDEA')
      .shadow(CardShadow)

      Row({ space: '12vp' }) {
        Button('自动定位')
          .layoutWeight(1)
          .height('44vp')
          .fontSize('15fp')
          .fontFamily(AppFont.FAMILY)
          .fontColor($r('app.color.button_text_on_primary'))
          .backgroundColor($r('app.color.button_background'))
          .borderRadius(AppRadius.MD)
          .shadow(ButtonShadow)
          .enabled(!this.viewOnly && this.tcpConnected)
          .opacity((!this.viewOnly && this.tcpConnected) ? 1 : 0.5)
          .onClick(() => this.startLocalize())

        Button(this.showNavPath ? '隐藏路径' : '导航路径')
          .layoutWeight(1)
          .height('44vp')
          .fontSize('15fp')
          .fontFamily(AppFont.FAMILY)
          .fontColor($r('app.color.text'))
          .backgroundColor($r('app.color.button_select_background'))
          .borderRadius(AppRadius.MD)
          .enabled(!this.viewOnly && this.tcpConnected)
          .opacity((!this.viewOnly && this.tcpConnected) ? 1 : 0.5)
          .onClick(() => {
            if (this.viewOnly) {
              promptAction.showToast({ message: '浏览模式无法查看导航路径' });
              return;
            }
            if (!this.tcpConnected) {
              promptAction.showToast({ message: '请先连接小车' });
              return;
            }
            this.showNavPath = !this.showNavPath;
            promptAction.showToast({
              message: this.showNavPath ? '导航路径显示预留中' : '已隐藏导航路径'
            });
          })
      }
      .width('100%')
      .padding({ left: '16vp', right: '16vp' })

      Column() {
        StyledText({
          content: '建图/定位/导航路径接口预留中，后续版本接入',
          variant: TextVariant.Caption,
          textAlign: TextAlign.Center
        })
      }
      .width('100%')
      .padding({ bottom: '8vp' })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.window_background'))
  }
}
