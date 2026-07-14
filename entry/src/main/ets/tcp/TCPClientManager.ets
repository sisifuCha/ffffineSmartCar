// 1. import 需要的 socket 模块。
import socket from '@ohos.net.socket';
import { BusinessError } from '@ohos.base';
import promptAction from '@ohos.promptAction';
import { DualCarStatusManager } from './DualCarStatusManager';

const TAG = "TCPClientManager";

/** TCP 连接结果，含失败阶段与原因说明 */
export class TcpConnectResult {
  success: boolean = false;
  target: string = '';
  stage: string = '';
  reason: string = '';
  errorCode: number = 0;

  getDetailMessage(): string {
    if (this.success) {
      return `已成功连接 ${this.target}`;
    }
    const lines: string[] = [
      `连接目标：${this.target}`,
      `失败阶段：${this.stage}`,
      this.reason
    ];
    if (this.errorCode !== 0) {
      lines.push(`系统错误码：${this.errorCode}`);
    }
    lines.push('请检查：① 手机与小车同一 WiFi  ② 小车已开机  ③ IP 与 TCP 端口正确（默认 6000）');
    return lines.join('\n');
  }

  getShortMessage(): string {
    if (this.success) {
      return `已连接 ${this.target}`;
    }
    return `${this.stage}：${this.reason}`;
  }
}


/** socket 错误解析结果 */
class SocketErrorInfo {
  stage: string = '';
  reason: string = '';
  errorCode: number = 0;
}

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
  private socket: socket.TCPSocket = socket.constructTCPSocketInstance();
  /** 防止并发 connect 导致 2301115 */
  private isConnecting: boolean = false;
  /**
   * 网络配置类
   */
  private options: socket.TCPConnectOptions = {
    address: {
      address: "127.0.0.1",
      // family?: number,
      port: 12345
    },
    // 真机偶发慢；3s 偏紧，容易停在「连接小车 TCP」
    timeout: 8000
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
   * @returns 连接结果（含失败原因）
   */
  public async connect(): Promise<TcpConnectResult> {
    if (this.isConnecting) {
      const busy = new TcpConnectResult();
      busy.target = `${this.options.address.address}:${this.options.address.port}`;
      busy.stage = '连接小车 TCP';
      busy.reason = '正在连接中，请勿重复点击';
      busy.errorCode = 2301115;
      return busy;
    }

    this.isConnecting = true;
    try {
      return await this.connectOnce(false);
    } finally {
      this.isConnecting = false;
    }
  }

  private async connectOnce(isRetry: boolean): Promise<TcpConnectResult> {
    const result = new TcpConnectResult();
    result.target = `${this.options.address.address}:${this.options.address.port}`;

    await this.resetSocketAsync();

    try {
      result.stage = '绑定本地端口';
      await this.socket.bind({ address: '0.0.0.0', family: 1 });

      result.stage = '连接小车 TCP';
      await this.socket.connect(this.options);

      // HarmonyOS 上 connect() 成功后 getState().isConnected 偶发仍为 false，
      // 旧逻辑会误报失败。只要 connect 未抛错，再短等一次状态即可。
      let ok = await this.isConnect();
      if (!ok) {
        await TCPClientManager.delay(200);
        ok = await this.isConnect();
      }
      if (!ok) {
        console.warn(TAG, 'getState 未及时变为 connected，仍按 connect 成功继续');
      }

      console.log(TAG, '连接成功', result.target);
      this.socket.on('message', (value: SocketInfo) => {
        console.log(TAG, `receiveMessage`, 'message');
        let messageView = '';

        for (let i: number = 0; i < value.message.byteLength; i++) {
          const uint8Array = new Uint8Array(value.message);
          const messages = uint8Array[i];
          const message = String.fromCharCode(messages);
          messageView += message;
        }

        console.log(TAG, `receiveMessage`, messageView);
        try {
          if (!DualCarStatusManager.dispatch(messageView)) {
            TCPClientManager._receiveMessage(messageView);
          }
        } catch (e) {
          console.error(TAG, 'MESSAGE ERROR', JSON.stringify(e));
        }
      });

      result.success = true;
      return result;
    } catch (err) {
      const parsed = TCPClientManager.parseSocketError(err, result.stage, result.target);
      const errMsg = (err as BusinessError).message ?? '';
      const shouldRetry = !isRetry &&
        (parsed.errorCode === 2301115 || errMsg.toLowerCase().includes('in progress'));

      if (shouldRetry) {
        console.warn(TAG, 'connect retry after 2301115');
        await TCPClientManager.delay(400);
        return await this.connectOnce(true);
      }

      result.stage = parsed.stage;
      result.reason = parsed.reason;
      result.errorCode = parsed.errorCode;
      console.error(TAG, 'connect failed', result.getDetailMessage());
      await this.resetSocketAsync();
      return result;
    }
  }

  private static delay(ms: number): Promise<void> {
    return new Promise<void>((resolve) => {
      setTimeout(() => resolve(), ms);
    });
  }

  /** 连接前/失败后重建 socket，等待系统释放资源 */
  private async resetSocketAsync(): Promise<void> {
    try {
      await this.socket.close();
    } catch (e) {
      console.warn(TAG, 'close socket warn', JSON.stringify(e));
    }
    this.socket = socket.constructTCPSocketInstance();
    await TCPClientManager.delay(150);
  }

  private static parseSocketError(err: Object, stage: string, target: string): SocketErrorInfo {
    const info = new SocketErrorInfo();
    const biz = err as BusinessError;
    info.errorCode = biz.code ?? 0;
    info.stage = stage;
    const msg = (biz.message ?? JSON.stringify(err)).toLowerCase();
    let reason = biz.message ?? '未知网络错误';

    if (msg.includes('timeout') || msg.includes('timed out')) {
      reason = `连接 ${target} 超时（3 秒），请确认 IP 正确且手机与小车在同一 WiFi`;
    } else if (info.errorCode === 2301115 || msg.includes('in progress')) {
      reason = '上次连接尚未结束或点击过快，请等待 1 秒后重试';
    } else if (msg.includes('refused') || msg.includes('econnrefused') || info.errorCode === 2301009) {
      reason = `连接被拒绝，请确认小车已开机且 TCP 端口已开启（当前 ${target.split(':')[1]}）`;
    } else if (msg.includes('unreachable') || msg.includes('enetunreach') || msg.includes('no route')) {
      reason = '网络不可达，请检查手机 WiFi 是否已连接且与小车同网段';
    } else if (msg.includes('permission') || msg.includes('denied')) {
      reason = '缺少网络权限，请检查 App 是否允许访问网络';
    } else if (stage === '绑定本地端口') {
      reason = `本机端口绑定失败：${biz.message ?? '请稍后重试'}`;
    }

    info.reason = reason;
    return info;
  }

  /**
   * 判断网络是否连接成功
   * @returns
   */
  public async isConnect() {
    if (this.socket == null) {
      return false;
    }

    try {
      const state = await this.socket.getState();
      console.log(TAG, `isConnect`,
        `isClose = ${state.isClose} ` +
          `isConnected = ${state.isConnected}`);
      return state.isClose === false && state.isConnected === true;
    } catch (e) {
      console.warn(TAG, 'isConnect error', JSON.stringify(e));
      return false;
    }
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
    const result = await this.connect();
    return result.success;

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