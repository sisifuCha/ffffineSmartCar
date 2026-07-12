import socket from '@ohos.net.socket';
import { LocalizationManager } from './LocalizationManager';

const TAG = 'LocLink';

class SocketInfo {
  message: ArrayBuffer = new ArrayBuffer(1);
  remoteInfo: socket.SocketRemoteInfo = {} as socket.SocketRemoteInfo;
}

/** 定位专用 TCP 连接（:6600） */
export class LocLink {
  private static instance: LocLink | undefined = undefined;

  private constructor() {
  }

  public static getInstance(): LocLink {
    if (!LocLink.instance) {
      LocLink.instance = new LocLink();
    }
    return LocLink.instance;
  }

  private socket: socket.TCPSocket = socket.constructTCPSocketInstance();
  private options: socket.TCPConnectOptions = {
    address: {
      address: '127.0.0.1',
      port: 6600
    },
    timeout: 3000
  };

  initNetAddress(netAddress: socket.NetAddress): void {
    if (netAddress.address) {
      this.options.address.address = netAddress.address;
    }
    if (netAddress.family) {
      this.options.address.family = netAddress.family;
    }
    if (netAddress.port) {
      this.options.address.port = netAddress.port;
    }
  }

  public async connect(): Promise<boolean> {
    const connected = await this.isConnect();
    if (connected) {
      this.socket.close();
    }

    try {
      await this.socket.bind({ address: '0.0.0.0', family: 1 });
      await this.socket.connect(this.options);
      if (!(await this.isConnect())) {
        this.socket.close();
        return false;
      }

      this.socket.on('message', (value: SocketInfo) => {
        let messageView = '';
        for (let i = 0; i < value.message.byteLength; i++) {
          const uint8Array = new Uint8Array(value.message);
          messageView += String.fromCharCode(uint8Array[i]);
        }
        try {
          LocalizationManager.dispatch(messageView);
        } catch (e) {
          console.error(TAG, 'MESSAGE ERROR', JSON.stringify(e));
        }
      });
      return true;
    } catch {
      this.socket.close();
      return false;
    }
  }

  public async isConnect(): Promise<boolean> {
    if (this.socket == null) {
      return false;
    }
    const state = await this.socket.getState();
    return state.isClose === false && state.isConnected === true;
  }

  public async sendMessage(message: string): Promise<boolean> {
    if (await this.isConnect()) {
      this.socket.send({ data: message });
      return true;
    }
    await this.connect();
    return false;
  }

  public closeConnection(): void {
    this.socket.close();
  }
}
