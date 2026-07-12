/**
 * TCP 接收解析：按 $...# 拆帧，校验并更新小车状态
 */
import promptAction from '@ohos.promptAction';
import { CarDecode, CarReceiveFrame } from '../CarUtill/CarDecode';
import { CarStatusStore } from '../model/CarStatusStore';
import { PreferencesUtils } from '../utils/PreferencesUtils';
import { TCPClientManager } from './TCPClientManager';

const TAG = 'TCPClientReceiveUtils';

export class TCPClientReceiveUtils {
  private static messageBuffer: string = '';
  private static initialized: boolean = false;
  /** 低电告警防抖：上次告警时的电压档位 */
  private static lastAlertVoltage: number = -1;

  /** 注册 TCP 接收回调，应在连接成功后调用 */
  public static init(): void {
    if (TCPClientReceiveUtils.initialized) {
      return;
    }
    CarStatusStore.init();
    TCPClientManager.receiveMessage = TCPClientReceiveUtils.onMessage;
    TCPClientReceiveUtils.initialized = true;
    console.log(TAG, 'init');
  }

  public static onMessage(message: string): void {
    if (!message) {
      return;
    }

    TCPClientReceiveUtils.messageBuffer += message;
    const result = CarDecode.extractFrames(TCPClientReceiveUtils.messageBuffer);
    TCPClientReceiveUtils.messageBuffer = result.remain;

    for (let i = 0; i < result.frames.length; i++) {
      TCPClientReceiveUtils.handleFrame(result.frames[i]);
    }
  }

  private static handleFrame(frame: CarReceiveFrame): void {
    console.log(TAG, 'frame', frame.cmd, frame.info);

    if (frame.cmd === '02') {
      TCPClientReceiveUtils.handleBatteryFrame(frame);
    }
  }

  private static async handleBatteryFrame(frame: CarReceiveFrame): Promise<void> {
    const voltage = CarDecode.parseBatteryVoltage(frame.info);
    if (voltage === undefined || voltage <= 0) {
      console.warn(TAG, 'invalid battery data', frame.raw);
      return;
    }

    let minV = 7.0;
    let maxV = 8.4;
    let alertEnabled = true;
    let alertThreshold = 7.2;

    try {
      const statusPref = PreferencesUtils.getInstance().statusUtils;
      minV = await statusPref.getVoltageMin();
      maxV = await statusPref.getVoltageMax();
      alertEnabled = await statusPref.getLowBatteryAlertEnabled();
      alertThreshold = await statusPref.getLowBatteryThreshold();
    } catch (e) {
      console.warn(TAG, 'use default battery prefs', JSON.stringify(e));
    }

    CarStatusStore.updateBattery(voltage, minV, maxV);
    CarStatusStore.setConnected(true);

    if (alertEnabled && voltage <= alertThreshold) {
      TCPClientReceiveUtils.tryLowBatteryAlert(voltage, alertThreshold);
    } else if (voltage > alertThreshold + 0.1) {
      TCPClientReceiveUtils.lastAlertVoltage = -1;
    }
  }

  private static tryLowBatteryAlert(voltage: number, threshold: number): void {
    const bucket = Math.floor(voltage * 10);
    if (TCPClientReceiveUtils.lastAlertVoltage === bucket) {
      return;
    }
    TCPClientReceiveUtils.lastAlertVoltage = bucket;
    promptAction.showToast({
      message: `低电告警：当前 ${voltage.toFixed(2)}V，低于 ${threshold.toFixed(1)}V`
    });
  }
}
