import { CarDecode } from '../CarUtill/CarDecode';

/** 小车状态全局存储，供 UI 通过 AppStorage 订阅 */
export class CarStatusStore {
  static readonly KEY_VOLTAGE = 'car_battery_voltage';
  static readonly KEY_PERCENT = 'car_battery_percent';
  static readonly KEY_CONNECTED = 'car_status_connected';
  static readonly KEY_LAST_UPDATE = 'car_status_last_update';

  static init(): void {
    AppStorage.setOrCreate(CarStatusStore.KEY_VOLTAGE, 0);
    AppStorage.setOrCreate(CarStatusStore.KEY_PERCENT, 0);
    AppStorage.setOrCreate(CarStatusStore.KEY_CONNECTED, false);
    AppStorage.setOrCreate(CarStatusStore.KEY_LAST_UPDATE, 0);
  }

  static updateBattery(voltage: number, minV: number, maxV: number): void {
    const percent = CarDecode.voltageToPercent(voltage, minV, maxV);
    AppStorage.set(CarStatusStore.KEY_VOLTAGE, voltage);
    AppStorage.set(CarStatusStore.KEY_PERCENT, percent);
    AppStorage.set(CarStatusStore.KEY_LAST_UPDATE, Date.now());
  }

  static setConnected(connected: boolean): void {
    AppStorage.set(CarStatusStore.KEY_CONNECTED, connected);
  }
}
