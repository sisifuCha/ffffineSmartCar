/**
 * 小车状态面板（竖屏）
 */
import promptAction from '@ohos.promptAction';
import { carApi } from '../CarUtill/CarApi';
import { AppSession } from '../model/AppSession';
import { CarStatusStore } from '../model/CarStatusStore';
import { AppRadius, ButtonShadow, CardShadow } from '../styles/styles';
import { AppFont, StyledText, TextVariant } from '../styles/Typography';
import { TCPClientManager } from '../tcp/TCPClientManager';
import { PreferencesUtils } from '../utils/PreferencesUtils';

@Component
export struct StatusPanel {
  @Prop isActive: boolean = false;
  @StorageLink(CarStatusStore.KEY_VOLTAGE) batteryVoltage: number = 0;
  @StorageLink(CarStatusStore.KEY_PERCENT) batteryPercent: number = 0;
  @StorageLink(CarStatusStore.KEY_CONNECTED) statusConnected: boolean = false;
  @StorageLink(CarStatusStore.KEY_LAST_UPDATE) lastUpdate: number = 0;
  @StorageLink(AppSession.KEY_VIEW_ONLY) viewOnly: boolean = false;
  @StorageLink(AppSession.KEY_TCP_CONNECTED) tcpConnected: boolean = false;

  @State alertEnabled: boolean = true;
  @State alertThreshold: string = '7.2';
  @State voltageMin: string = '7.0';
  @State voltageMax: string = '8.4';
  @State polling: boolean = false;

  aboutToAppear(): void {
    CarStatusStore.init();
    this.loadSettings();
    this.startBatteryPolling();
  }

  aboutToDisappear(): void {
    this.polling = false;
  }

  private loadSettings(): void {
    const statusPref = PreferencesUtils.getInstance().statusUtils;
    statusPref.getLowBatteryAlertEnabled().then((v: boolean) => this.alertEnabled = v);
    statusPref.getLowBatteryThreshold().then((v: number) => this.alertThreshold = this.formatVoltage(v));
    statusPref.getVoltageMin().then((v: number) => this.voltageMin = this.formatVoltage(v));
    statusPref.getVoltageMax().then((v: number) => this.voltageMax = this.formatVoltage(v));
  }

  private formatVoltage(v: number): string {
    return v.toFixed(1);
  }

  private async startBatteryPolling(): Promise<void> {
    if (this.viewOnly) {
      return;
    }
    const connected = await TCPClientManager.getInstance().isConnect();
    if (!connected) {
      return;
    }
    this.polling = true;
    this.requestBatteryOnce();
    const poll = async () => {
      if (!this.polling) {
        return;
      }
      if (await TCPClientManager.getInstance().isConnect()) {
        carApi.requestBattery();
      }
      setTimeout(poll, 3000);
    };
    setTimeout(poll, 3000);
  }

  private requestBatteryOnce(): void {
    if (this.viewOnly) {
      promptAction.showToast({ message: '浏览模式无法获取实时数据' });
      return;
    }
    carApi.requestBattery();
  }

  private async saveSettings(): Promise<void> {
    const threshold = Number.parseFloat(this.alertThreshold);
    const minV = Number.parseFloat(this.voltageMin);
    const maxV = Number.parseFloat(this.voltageMax);

    if (Number.isNaN(threshold) || threshold <= 0) {
      promptAction.showToast({ message: '告警电压格式不正确' });
      return;
    }
    if (Number.isNaN(minV) || Number.isNaN(maxV) || maxV <= minV) {
      promptAction.showToast({ message: '电压范围设置不正确' });
      return;
    }

    const statusPref = PreferencesUtils.getInstance().statusUtils;
    await statusPref.setLowBatteryAlertEnabled(this.alertEnabled);
    await statusPref.setLowBatteryThreshold(threshold);
    await statusPref.setVoltageMin(minV);
    await statusPref.setVoltageMax(maxV);
    promptAction.showToast({ message: '设置已保存' });
    this.requestBatteryOnce();
  }

  private gaugeColor(): ResourceColor {
    if (this.batteryPercent <= 20) {
      return '#C9A89A';
    }
    if (this.batteryPercent <= 40) {
      return '#C4B08A';
    }
    return $r('app.color.button_background');
  }

  private statusHint(): string {
    if (this.viewOnly) {
      return '浏览模式 · 连接小车后可获取实时电量';
    }
    if (this.statusConnected && this.lastUpdate > 0) {
      return '数据已连接';
    }
    if (this.tcpConnected) {
      return '正在请求电池数据…';
    }
    return '未连接小车';
  }

  build() {
    Scroll() {
      Column({ space: '14vp' }) {
        Column({ space: '16vp' }) {
          Text('实时电量')
            .fontFamily(AppFont.FAMILY)
            .fontSize('15fp')
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text'))
            .width('100%')
          Text('圆环显示电量百分比，中间数字为当前电压（连接小车后自动刷新）')
            .fontFamily(AppFont.FAMILY)
            .fontSize('12fp')
            .fontColor($r('app.color.text_secondary'))
            .width('100%')

          Stack() {
            Progress({
              value: this.batteryPercent,
              total: 100,
              type: ProgressType.Ring
            })
              .width('150vp')
              .height('150vp')
              .color(this.gaugeColor())
              .backgroundColor('#EEEDEA')
              .style({ strokeWidth: 10 })

            Column({ space: '4vp' }) {
              StyledText({
                content: this.viewOnly ? '--' : `${this.batteryPercent}%`,
                variant: TextVariant.Metric
              })
              StyledText({
                content: this.viewOnly ? '-- V' : `${this.batteryVoltage.toFixed(2)} V`,
                variant: TextVariant.Subtitle
              })
            }
          }

          StyledText({ content: this.statusHint(), variant: TextVariant.Status })

          if (!this.viewOnly && this.lastUpdate > 0) {
            StyledText({
              content: `最近更新：${new Date(this.lastUpdate).toLocaleTimeString()}`,
              variant: TextVariant.Caption
            })
          }

          Button('刷新电压')
            .width('140vp')
            .height('40vp')
            .fontSize('14fp')
            .fontFamily(AppFont.FAMILY)
            .fontColor($r('app.color.button_text_on_primary'))
            .backgroundColor($r('app.color.button_background'))
            .borderRadius(AppRadius.MD)
            .shadow(ButtonShadow)
            .enabled(!this.viewOnly && this.tcpConnected)
            .opacity((!this.viewOnly && this.tcpConnected) ? 1 : 0.5)
            .onClick(() => this.requestBatteryOnce())

          Text('手动向小车请求一次最新电池电压')
            .fontFamily(AppFont.FAMILY)
            .fontSize('12fp')
            .fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .padding('20vp')
        .alignItems(HorizontalAlign.Center)
        .backgroundColor($r('app.color.card_background'))
        .borderRadius(AppRadius.LG)
        .border({ width: 1, color: $r('app.color.card_border') })
        .shadow(CardShadow)

        Column({ space: '12vp' }) {
          Text('低电告警设置')
            .fontFamily(AppFont.FAMILY)
            .fontSize('15fp')
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text'))
            .width('100%')
          Text('电压低于告警阈值时弹出提醒，请按实际电池规格填写')
            .fontFamily(AppFont.FAMILY)
            .fontSize('12fp')
            .fontColor($r('app.color.text_secondary'))
            .width('100%')

          Row({ space: '10vp' }) {
            Checkbox({ name: 'lowBatteryAlert', group: 'status' })
              .select(this.alertEnabled)
              .onChange((value: boolean) => this.alertEnabled = value)
            Text('开启低电告警')
              .fontFamily(AppFont.FAMILY)
              .fontSize('15fp')
              .fontColor($r('app.color.text'))
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          Text('勾选后，电量低于下方「告警电压」时会提示充电')
            .fontFamily(AppFont.FAMILY)
            .fontSize('12fp')
            .fontColor($r('app.color.text_secondary'))
            .width('100%')

          StatusSettingRow({
            label: '告警电压',
            hint: '低于此电压时触发告警（V）',
            value: this.alertThreshold,
            onChange: (v: string) => this.alertThreshold = v
          })

          StatusSettingRow({
            label: '最低电压',
            hint: '对应 0% 电量的电压（V）',
            value: this.voltageMin,
            onChange: (v: string) => this.voltageMin = v
          })

          StatusSettingRow({
            label: '满电电压',
            hint: '对应 100% 电量的电压（V）',
            value: this.voltageMax,
            onChange: (v: string) => this.voltageMax = v
          })

          Button('保存设置')
            .width('100%')
            .height('44vp')
            .fontSize('15fp')
            .fontFamily(AppFont.FAMILY)
            .fontColor($r('app.color.button_text_on_primary'))
            .backgroundColor($r('app.color.button_background'))
            .borderRadius(AppRadius.MD)
            .shadow(ButtonShadow)
            .onClick(() => this.saveSettings())

          StyledText({
            content: '保存后生效；电量数据通过 TCP cmd 02 从小车获取',
            variant: TextVariant.Caption
          })
        }
        .width('100%')
        .padding('20vp')
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

@Component
struct StatusSettingRow {
  @Prop label: string = '';
  @Prop hint: string = '';
  @Prop value: string = '';
  onChange: (value: string) => void = () => {
  };

  build() {
    Column({ space: '6vp' }) {
      Row() {
        Text(this.label)
          .width('88vp')
          .fontFamily(AppFont.FAMILY)
          .fontSize('15fp')
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text'))
        TextInput({ text: this.value, placeholder: this.hint })
          .layoutWeight(1)
          .height('44vp')
          .fontFamily(AppFont.FAMILY)
          .fontSize('15fp')
          .placeholderColor($r('app.color.text_secondary'))
          .backgroundColor($r('app.color.edit_text_background'))
          .borderRadius(AppRadius.SM)
          .padding({ left: '14vp', right: '14vp' })
          .onChange((v: string) => this.onChange(v))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .margin({ top: '4vp' })
  }
}
