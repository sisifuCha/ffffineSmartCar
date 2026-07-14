/**
 * HTTP 传感器客户端：从 http://{ip}:{sensorPort}/ 拉取 JSON 传感器数据
 * 解析后的键值对通过 SensorDataStore 更新到 AppStorage
 */
import http from '@ohos.net.http';
import { SensorDataStore } from '../model/SensorDataStore';
import { PreferencesUtils } from '../utils/PreferencesUtils';

const TAG = 'SensorHttpClient';

export class SensorHttpClient {
  private static instance: SensorHttpClient | undefined = undefined;
  private pollTimer: number = -1;
  private polling: boolean = false;

  private constructor() {
  }

  public static getInstance(): SensorHttpClient {
    if (!SensorHttpClient.instance) {
      SensorHttpClient.instance = new SensorHttpClient();
    }
    return SensorHttpClient.instance;
  }

  /**
   * 启动 HTTP 传感器轮询（默认每 3 秒一次）
   */
  public startPolling(): void {
    if (this.polling) {
      return;
    }
    SensorDataStore.init();
    this.polling = true;
    this.fetchOnce();
    this.scheduleNext();
    console.info(TAG, 'polling started');
  }

  /** 停止轮询 */
  public stopPolling(): void {
    this.polling = false;
    if (this.pollTimer >= 0) {
      clearTimeout(this.pollTimer);
      this.pollTimer = -1;
    }
    SensorDataStore.markDisconnected();
    console.info(TAG, 'polling stopped');
  }

  private scheduleNext(): void {
    this.pollTimer = setTimeout(async () => {
      if (!this.polling) {
        return;
      }
      await this.fetchOnce();
      this.scheduleNext();
    }, 3000);
  }

  /** 执行一次 HTTP GET 请求，依次尝试 / 与 /status */
  public async fetchOnce(): Promise<void> {
    try {
      const netUtils = PreferencesUtils.getInstance().netUtils;
      const ip = await netUtils.getIP();
      const port = await netUtils.getSensorPort();

      // 优先 /status（JSON API），回退 /
      const statusOk = await this.tryFetch(ip, port, '/status');
      if (statusOk) {
        return;
      }
      await this.tryFetch(ip, port, '/');
    } catch (e) {
      console.warn(TAG, 'fetch error', JSON.stringify(e));
      SensorDataStore.markDisconnected();
    }
  }

  private async tryFetch(ip: string, port: string, path: string): Promise<boolean> {
    let client: http.HttpRequest | undefined = undefined;
    try {
      const url = `http://${ip}:${port}${path}`;
      console.info(TAG, 'try', url);

      client = http.createHttp();
      const resp = await client.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 3000,
        readTimeout: 3000
      });

      if (resp.responseCode === 200 && typeof resp.result === 'string') {
        const body = resp.result as string;
        console.info(TAG, 'response length', body.length);
        // 尝试解析为 JSON
        if (SensorDataStore.updateFromJson(body)) {
          console.info(TAG, 'parsed ok from', path);
          return true;
        }
        console.warn(TAG, 'json parse failed for', path);
      } else {
        console.warn(TAG, 'bad response', resp.responseCode, 'from', path);
      }
    } catch (e) {
      console.warn(TAG, 'request failed for', path, JSON.stringify(e));
    } finally {
      if (client) {
        client.destroy();
      }
    }
    return false;
  }
}
