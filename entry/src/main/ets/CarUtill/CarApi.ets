import promptAction from '@ohos.promptAction';
import { AppSession } from '../model/AppSession';
import { TCPClientManager } from '../tcp/TCPClientManager'
import { CarEncode } from './CarEncode';
import { CarDirection } from './CarEnum';
import { TCPClientReceiveUtils } from '../tcp/TCPClientReceiveUtils';

class CarApi {
  /**
   *
   * @param d
   */
  carBtnCtrl(d: CarDirection) {
    this.send(CarEncode.ButtonCarEncode(d))
  }

  /** 初始化 TCP 回传解析 */
  initReceive() {
    TCPClientReceiveUtils.init();
  }

  /** 请求电池电压 */
  requestBattery() {
    this.send(CarEncode.GetBatteryVoltageEncode())
  }

  /** 急停：刹车并清零所有运动指令 */
  emergencyStop() {
    this.send(CarEncode.ButtonCarEncode(CarDirection.Brake));
    this.send(CarEncode.CtrlCarEncode(0, 0));
    this.send(CarEncode.UpSpeedCarEncode(0, 0, 0, 0));
  }

  send(message: string) {
    if (AppSession.isViewOnly()) {
      promptAction.showToast({ message: '浏览模式无法操控小车' });
      return;
    }
    if (!AppSession.isTcpConnected()) {
      promptAction.showToast({ message: '请先连接小车' });
      return;
    }
    TCPClientManager.getInstance().sendMessage(message)
  }
}


let carApi = (new CarApi())

export { carApi, }