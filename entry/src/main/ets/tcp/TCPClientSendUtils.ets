import { TCPClientManager } from './TCPClientManager';
import { carApi } from '../CarUtill/CarApi';

const TAG = "TCPClientSendUtils";

/**
 * TCP发送工具
 */
export class TCPClientSendUtils {
  /**私有静态实例，懒汉式单例*/
  private static instance: TCPClientSendUtils | undefined = undefined;
  private batteryTimer: number = -1;

  /**私有构造方法，防止外部直接实例化*/
  private constructor() {
  }

  /**提供一个公共的静态方法返回实例对象*/
  public static getInstance(): TCPClientSendUtils {
    if (!TCPClientSendUtils.instance)
      TCPClientSendUtils.instance = new TCPClientSendUtils();
    return TCPClientSendUtils.instance;
  }

  /**
   * 初始化心跳与状态轮询
   */
  public init() {
    carApi.initReceive();

    if (this.batteryTimer >= 0) {
      clearInterval(this.batteryTimer);
    }

    carApi.requestBattery();
    this.batteryTimer = setInterval(async () => {
      if (await TCPClientManager.getInstance().isConnect()) {
        carApi.requestBattery();
      }
    }, 3000);
  }
}
