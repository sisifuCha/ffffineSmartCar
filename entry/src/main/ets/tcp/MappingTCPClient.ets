import socket from '@ohos.net.socket';
import promptAction from '@ohos.promptAction';
import { PreferencesUtils } from '../utils/PreferencesUtils';

const TAG = 'MappingTCPClient';

class SocketInfo {
  message: ArrayBuffer = new ArrayBuffer(1);
  remoteInfo: socket.SocketRemoteInfo = {} as socket.SocketRemoteInfo;
}

/** 无人建图专用 TCP 客户端（端口 6002，# 后 8 位命令） */
export class MappingTCPClient {
  private static instance: MappingTCPClient;
  private socket: socket.TCPSocket = socket.constructTCPSocketInstance();
  private options: socket.TCPConnectOptions = {
    address: {
      address: '192.168.137.174',
      port: 6002
    },
    timeout: 3000
  };

  private constructor() {
  }

  public static getInstance(): MappingTCPClient {
    if (!MappingTCPClient.instance) {
      MappingTCPClient.instance = new MappingTCPClient();
    }
    return MappingTCPClient.instance;
  }

  public async connectFromPrefs(): Promise<boolean> {
    const netUtils = PreferencesUtils.getInstance().netUtils;
    const ip = await netUtils.getIP();
    const port = Number.parseInt(await netUtils.getMappingPort());
    this.options.address.address = ip;
    this.options.address.port = port;
    return this.connect();
  }

  public async connect(): Promise<boolean> {
    if (await this.isConnect()) {
      this.socket.close();
    }
    try {
      await this.socket.bind({ address: '0.0.0.0', family: 1 });
      await this.socket.connect(this.options);
      if (!(await this.isConnect())) {
        this.socket.close();
        return false;
      }
      console.log(TAG, 'connect ok', JSON.stringify(this.options.address));
      return true;
    } catch (e) {
      console.error(TAG, 'connect failed', JSON.stringify(e));
      this.socket.close();
      return false;
    }
  }

  public async isConnect(): Promise<boolean> {
    if (this.socket == null) {
      return false;
    }
    const state = await this.socket.getState();
    return state.isClose == false && state.isConnected == true;
  }

  public async send(message: string): Promise<boolean> {
    if (await this.isConnect()) {
      this.socket.send({ data: message });
      return true;
    }
    const ok = await this.connectFromPrefs();
    if (!ok) {
      promptAction.showToast({ message: '建图端口连接失败，请检查 6002 服务' });
      return false;
    }
    this.socket.send({ data: message });
    return true;
  }

  public closeConnection(): void {
    this.socket.close();
  }
}
