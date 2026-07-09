// 1. import 需要的 socket 模块。
import socket from '@ohos.net.socket';
import promptAction from '@ohos.promptAction';
import { DualCarStatusManager } from './DualCarStatusManager';

const TAG = "TCPClientManager";


class SocketInfo {
  message: ArrayBuffer = new ArrayBuffer(1);
  remoteInfo: socket.SocketRemoteInfo = {} as socket.SocketRemoteInfo;
}

/**
 * 全局tcp工具
 */
export class TCPClientManager {
  /**私有静态实例，懒汉式单例*/
  private static instance: TCPClientManager;

  /**私有构造方法，防止外部直接实例化*/
  private constructor() {
  }

  /**提供一个公共的静态方法返回实例对象*/
  public static getInstance(): TCPClientManager {
    // 如果对象单例不存在那么构建对象
    if (!TCPClientManager.instance)
      TCPClientManager.instance = new TCPClientManager();
    return TCPClientManager.instance;
  }

  /** 服务器对象 */
  private socket: socket.TCPSocket  = socket.constructTCPSocketInstance();
  /**
   * 网络配置类
   */
  private options: socket.TCPConnectOptions = {
    address: {
      address: "127.0.0.1",
      // family?: number,
      port: 12345
    },
    timeout: 3000
  }

  /**
   * 留给外部给网路信息初始化的接口
   * @param netAddress
   */
  initNetAddress(netAddress: socket.NetAddress) {
    console.log(TAG, 'initNetAddress', JSON.stringify(netAddress))

    if (netAddress.address) this.options.address.address = netAddress.address;
    if (netAddress.family) this.options.address.family = netAddress.family;
    if (netAddress.port) this.options.address.port = netAddress.port;
  }

  /**
   * 初始化连接（可以在需要时调用，或者放在构造方法中）
   * @returns 是否连接成功
   */
  public async connect() {

    // 异步函数，用来获取当前连接状态
    let isConnect = await this.isConnect()

    // 如果当前是连接成功的，那么先断开连接
    if (isConnect == true) {
      this.socket.close();
      // this.socket = undefined;
    }

    // this.socket = socket.constructTCPSocketInstance();
    try {
      // 绑定本机IP地址（在3.2R）
      await this.socket.bind({ address: '0.0.0.0', family: 1 })
      // 绑定目标服务端IP地址
      await this.socket.connect(this.options)
      if (!(await this.isConnect())) {
        this.socket.close();
        return false;
      }
      console.log(TAG, '连接成功')
      // 信号接收
      this.socket.on("message", (value: SocketInfo) => {

        console.log(TAG, `receiveMessage`, "message")
        let messageView = '';

        // 拼接字符串
        for (let i: number = 0; i < value.message.byteLength; i++) {
          let uint8Array = new Uint8Array(value.message);
          let messages = uint8Array[i];
          let message = String.fromCharCode(messages);
          messageView += message;
        }

        console.log(TAG, `receiveMessage`, messageView)
        // 接受数据 , 这里使用try catch 包裹是为了防止拿到垃圾数导致闪退
        try {
          if (!DualCarStatusManager.dispatch(messageView)) {
            TCPClientManager._receiveMessage(messageView);
          }
        } catch (e) {
          console.error(TAG, "MESSAGE ERROR", JSON.stringify(e))
        }


      })
      return true;
    } catch {
      // 如果连接失败需要断开连接
      // 在Mate50 HarmonyOS 4.2.0.130 API 9上连接失败 如果不断开导致下次无法正常连接
      this.socket.close();
      // this.socket = undefined;
      return false;
    }


  }

  /**
   * 判断网络是否连接成功
   * @returns
   */
  public async isConnect() {
    //如果没有创建socket连接，那么就算没有连接
    if (this.socket == null)
      return false;

    let state: socket.SocketStateBase | undefined = undefined;

    state = await this.socket.getState();
    console.log(TAG, `isConnect`,
      `state = ${state == undefined} `)

    console.log(TAG, `isConnect`,
      `isClose = ${state.isClose} ` +
        `isConnected = ${state.isConnected}`)
    // 如果没有断开连接 && 已经成功连接上
    return state.isClose == false
      && state.isConnected == true;
  }

  /**
   * 发送数据
   * @param message
   * @returns 是否连接成功
   */
  public async sendMessage(message: string) {
    console.log(TAG, `sendMessage`, `message=${message}`)
    // 如果正常那么发送数据
    if (await this.isConnect() == true) {
      console.log(TAG, `sendMessage-------------------------`, `message=${message}`)
      this.socket.send({ data: message })
      return true
    }

    // 如果断线了需要重连
    console.log(TAG, '正在重连')
    await this.connect();
    return false;

  }

  /**关闭连接*/
  public closeConnection() {
    this.socket.close()
  }

  /**
   * 日志输出
   * @param message
   */
  private showInfo(message: string) {
    promptAction.showToast({ message: message })
    console.log(TAG, message)
  }

  /**接收数据*/
  private static _receiveMessage = (message: string) => {
  };

  /** 接收数据的setder */
  public static set receiveMessage(value: (message: string) => void) {
    TCPClientManager._receiveMessage = value;
  }
}