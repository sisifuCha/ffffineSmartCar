/**
 * 地图页：用 WebView 加载 Jetson :8081 上的地图（与遥控视频同套路，更稳）
 * 车端需先跑: python3 ~/temp/auto_mapping/serve_map_for_app.py
 */
import web_webview from '@ohos.web.webview';
import http from '@ohos.net.http';
import promptAction from '@ohos.promptAction';
import { AppSession } from '../model/AppSession';
import { ButtonShadow, AppRadius, CardShadow } from '../styles/styles';
import { AppFont, StyledText, TextVariant } from '../styles/Typography';
import { PreferencesUtils } from '../utils/PreferencesUtils';

const MAP_PORT_DEFAULT = 8081;

@Component
export struct MapPanel {
  controller: web_webview.WebviewController = new web_webview.WebviewController();
  @State statusText: string = '正在准备地图地址…';
  @State showNavPath: boolean = false;
  @State mapPageUrl: string = '';
  @State mapMeta: string = '';
  @State serverOk: boolean = false;
  @State webKey: number = 0;
  @StorageLink(AppSession.KEY_VIEW_ONLY) viewOnly: boolean = false;
  @StorageLink(AppSession.KEY_TCP_CONNECTED) tcpConnected: boolean = false;

  private carIp: string = '192.168.1.11';
  private mapPort: number = MAP_PORT_DEFAULT;

  aboutToAppear(): void {
    this.loadConfigAndMap();
  }

  private buildPageUrl(): string {
    return `http://${this.carIp}:${this.mapPort}/?t=${Date.now()}`;
  }

  private async loadConfigAndMap(): Promise<void> {
    const net = PreferencesUtils.getInstance().netUtils;
    this.carIp = await net.getIP();
    this.mapPageUrl = this.buildPageUrl();
    this.webKey = Date.now();
    this.statusText = `尝试加载 ${this.mapPageUrl}`;
    this.serverOk = false;
    await this.probeServer();
  }

  private async probeServer(): Promise<void> {
    const metaUrl = `http://${this.carIp}:${this.mapPort}/map.json`;
    const client = http.createHttp();
    try {
      const resp = await client.request(metaUrl, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 5000,
        readTimeout: 5000
      });
      if (resp.responseCode === 200 && typeof resp.result === 'string') {
        const d = JSON.parse(resp.result) as Record<string, Object>;
        const w = Number(d['w'] ?? 0);
        const h = Number(d['h'] ?? 0);
        const res = Number(d['resolution'] ?? 0.05);
        this.mapMeta = `${w}×${h} · ${res} m/px · 源: yahboomcar`;
        this.serverOk = true;
        this.statusText = '地图服务在线 · 下方应显示建图结果';
        this.mapPageUrl = this.buildPageUrl();
        this.webKey += 1;
        return;
      }
      this.serverOk = false;
      this.statusText = `地图服务异常 HTTP ${resp.responseCode}`;
      this.mapMeta = '请在 Jetson 运行 serve_map_for_app.py';
    } catch (_e) {
      this.serverOk = false;
      this.statusText = '连不上地图服务（与遥控 TCP6000 无关）';
      this.mapMeta =
        `Jetson 执行:\npython3 ~/temp/auto_mapping/serve_map_for_app.py\n手机浏览器试: http://${this.carIp}:${this.mapPort}/map.png`;
    } finally {
      client.destroy();
    }
  }

  private refreshMap(): void {
    this.statusText = '刷新中…';
    this.loadConfigAndMap();
  }

  private startLocalize(): void {
    if (this.viewOnly) {
      promptAction.showToast({ message: '浏览模式无法发起定位' });
      return;
    }
    if (!this.tcpConnected) {
      promptAction.showToast({ message: '请先连接小车（TCP 6000）' });
      return;
    }
    promptAction.showToast({ message: '自动定位仍预留；请先确认地图已显示' });
  }

  build() {
    Column({ space: '10vp' }) {
      Column({ space: '4vp' }) {
        StyledText({
          content: this.statusText,
          variant: TextVariant.Status,
          textAlign: TextAlign.Center
        })
        StyledText({
          content: this.mapMeta.length > 0 ? this.mapMeta : `IP ${this.carIp} · 端口 ${this.mapPort}`,
          variant: TextVariant.Caption,
          textAlign: TextAlign.Center
        })
      }
      .width('100%')
      .padding({ left: '16vp', right: '16vp', top: '4vp' })

      Column() {
        if (this.serverOk && this.mapPageUrl.length > 0) {
          Web({
            src: this.mapPageUrl,
            controller: this.controller
          })
            .width('100%')
            .layoutWeight(1)
            .backgroundColor('#111111')
            .key(`mapweb_${this.webKey}`)
            .onErrorReceive(() => {
              this.serverOk = false;
              this.statusText = 'WebView 加载地图失败';
            })
            .onHttpErrorReceive(() => {
              this.serverOk = false;
              this.statusText = '地图 HTTP 错误';
            })
        } else {
          Column({ space: '10vp' }) {
            Text('地图未显示')
              .fontSize('16fp')
              .fontColor($r('app.color.text'))
            Text(
              '和「连接小车」不是一回事。\n' +
                '需要 Jetson 另开地图服务（8081）。\n\n' +
                '1. scp serve_map_for_app.py 到车上\n' +
                '2. python3 ~/temp/auto_mapping/serve_map_for_app.py\n' +
                '3. 手机浏览器打开:\n' +
                `   http://${this.carIp}:${this.mapPort}/map.png\n` +
                '4. 浏览器能看再点「刷新地图」'
            )
              .fontSize('12fp')
              .fontColor($r('app.color.text_secondary'))
              .textAlign(TextAlign.Start)
              .width('100%')
          }
          .width('100%')
          .layoutWeight(1)
          .padding('16vp')
          .justifyContent(FlexAlign.Center)
        }
      }
      .width('100%')
      .layoutWeight(1)
      .margin({ left: '16vp', right: '16vp' })
      .borderRadius(AppRadius.LG)
      .clip(true)
      .border({ width: 1, color: $r('app.color.card_border') })
      .backgroundColor('#EEEDEA')
      .shadow(CardShadow)

      Row({ space: '12vp' }) {
        Button('刷新地图')
          .layoutWeight(1)
          .height('44vp')
          .fontSize('15fp')
          .fontFamily(AppFont.FAMILY)
          .fontColor($r('app.color.button_text_on_primary'))
          .backgroundColor($r('app.color.button_background'))
          .borderRadius(AppRadius.MD)
          .shadow(ButtonShadow)
          .onClick(() => this.refreshMap())

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
      }
      .width('100%')
      .padding({ left: '16vp', right: '16vp' })

      Button(this.showNavPath ? '隐藏路径' : '导航路径')
        .width('100%')
        .height('44vp')
        .margin({ left: '16vp', right: '16vp' })
        .fontSize('15fp')
        .fontFamily(AppFont.FAMILY)
        .fontColor($r('app.color.text'))
        .backgroundColor($r('app.color.button_select_background'))
        .borderRadius(AppRadius.MD)
        .enabled(!this.viewOnly && this.tcpConnected)
        .opacity((!this.viewOnly && this.tcpConnected) ? 1 : 0.5)
        .onClick(() => {
          this.showNavPath = !this.showNavPath;
          promptAction.showToast({
            message: this.showNavPath ? '导航路径显示预留中' : '已隐藏'
          });
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.window_background'))
  }
}
