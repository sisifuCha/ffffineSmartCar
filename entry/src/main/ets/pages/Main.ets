/**
 * App 主壳：四栏底部导航（竖屏）
 */
import router from '@ohos.router';
import { BottomNavBar, NavTabItem } from '../components/BottomNavBar';
import { AppSession } from '../model/AppSession';
import { TCPClientSendUtils } from '../tcp/TCPClientSendUtils';
import { TCPClientManager } from '../tcp/TCPClientManager';
import { SensorHttpClient } from '../http/SensorHttpClient';
import { MapPanel } from './MapPage';
import { MecanumWheelPanel } from './MecanumWheel';
import { RemoteControlPanel } from './RemoteControl';
import { StatusPanel } from './Status';
import { AppFont, StyledText, TextVariant } from '../styles/Typography';
import { AppRadius } from '../styles/styles';
import { ScreenUtils } from '../utils/ScreenUtils';

@Entry
@Component
struct Main {
  @State currentTab: number = 0;
  @StorageLink(AppSession.KEY_VIEW_ONLY) viewOnly: boolean = false;
  @StorageLink(AppSession.KEY_TCP_CONNECTED) tcpConnected: boolean = false;
  @StorageProp(ScreenUtils.SAFE_AREA_TOP_KEY) safeAreaTopPx: number = 36;

  private navTabs: NavTabItem[] = [
    { label: '麦克纳姆', icon: $r('app.media.tire') },
    { label: '遥控', icon: $r('app.media.icon_remote') },
    { label: '地图', icon: $r('app.media.icon_map') },
    { label: '电池', icon: $r('app.media.icon_battery') }
  ];

  private tabTitles: string[] = ['麦克纳姆', '遥控', '地图', '电池状态'];

  private tabHints: string[] = [
    '四轮独立调速 · 急停 · 滑块控制',
    '方向按钮/摇杆 · 实时视频 · 自动循迹',
    '查看地图 · 自动定位/导航路径（预留）',
    '查看实时电量 · 设置低电告警阈值'
  ];

  aboutToAppear(): void {
    this.ensureServices();
  }

  aboutToDisappear(): void {
    SensorHttpClient.getInstance().stopPolling();
  }

  private async ensureServices(): Promise<void> {
    SensorHttpClient.getInstance().startPolling();
    if (this.viewOnly) {
      return;
    }
    const connected = await TCPClientManager.getInstance().isConnect();
    if (connected) {
      AppSession.enterConnected();
      TCPClientSendUtils.getInstance().init();
    }
  }

  private goToConnect(): void {
    if (this.viewOnly) {
      AppSession.exitViewOnly();
    }
    router.replaceUrl({ url: 'pages/NetworkSettings' });
  }

  @Builder
  private headerActionButton(label: string, primary: boolean) {
    Text(label)
      .fontFamily(AppFont.FAMILY)
      .fontSize('14fp')
      .fontWeight(FontWeight.Medium)
      .letterSpacing(0.3)
      .fontColor(primary ? $r('app.color.button_text_on_primary') : $r('app.color.nav_active'))
      .padding({
        left: '14vp',
        right: '14vp',
        top: '8vp',
        bottom: '8vp'
      })
      .backgroundColor(primary ? $r('app.color.button_background') : $r('app.color.button_select_background'))
      .borderRadius(AppRadius.MD)
      .onClick(() => this.goToConnect())
  }

  build() {
    Column() {
      Row() {
        Column({ space: '4vp' }) {
          Text(this.tabTitles[this.currentTab])
            .fontFamily(AppFont.FAMILY)
            .fontSize('22fp')
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text'))
          StyledText({
            content: this.tabHints[this.currentTab],
            variant: TextVariant.Caption
          })
          if (!this.viewOnly && this.tcpConnected) {
            StyledText({
              content: '已连接小车',
              variant: TextVariant.Caption,
              hasCustomColor: true,
              customColor: $r('app.color.success_text')
            })
          } else if (this.viewOnly) {
            StyledText({
              content: '浏览中 · 未连接',
              variant: TextVariant.Caption
            })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        if (this.viewOnly) {
          this.headerActionButton('去连接', true)
        } else if (!this.tcpConnected) {
          this.headerActionButton('连接', false)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .padding({
        left: '20vp',
        right: '20vp',
        top: `${Math.max(this.safeAreaTopPx, 36) + 12}px`,
        bottom: '8vp'
      })

      Column() {
        if (this.currentTab === 0) {
          MecanumWheelPanel()
        } else if (this.currentTab === 1) {
          RemoteControlPanel()
        } else if (this.currentTab === 2) {
          MapPanel()
        } else {
          StatusPanel({ isActive: true })
        }
      }
      .width('100%')
      .layoutWeight(1)

      BottomNavBar({
        currentIndex: $currentTab,
        tabs: this.navTabs
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.window_background'))
  }
}
