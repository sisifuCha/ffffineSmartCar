const TAG = 'CarDecode';

/** 解析后的单条 TCP 回传帧 */
export interface CarReceiveFrame {
  vehicleType: string;
  cmd: string;
  info: string;
  raw: string;
}

export namespace CarDecode {

  /**
   * 从原始字符串中提取并解析所有完整帧（$...#）
   */
  export function extractFrames(buffer: string): ExtractResult {
    const frames: CarReceiveFrame[] = [];
    let remain = buffer;
    let start = remain.indexOf('$');

    while (start >= 0) {
      const end = remain.indexOf('#', start);
      if (end < 0) {
        remain = remain.substring(start);
        break;
      }

      const raw = remain.substring(start, end + 1);
      const frame = parseFrame(raw);
      if (frame) {
        frames.push(frame);
      }

      remain = remain.substring(end + 1);
      start = remain.indexOf('$');
    }

    return { frames, remain };
  }

  /**
   * 解析单帧，校验失败返回 undefined
   */
  export function parseFrame(raw: string): CarReceiveFrame | undefined {
    if (!raw.startsWith('$') || !raw.endsWith('#')) {
      return undefined;
    }

    const body = raw.substring(1, raw.length - 1);
    if (body.length < 10) {
      return undefined;
    }

    const vehicleType = body.substring(0, 2);
    const cmd = body.substring(2, 4);
    const sizeHex = body.substring(4, 6);
    const dataSize = hexToNumber(sizeHex);
    if (Number.isNaN(dataSize) || dataSize < 2) {
      return undefined;
    }

    const infoLen = (dataSize - 2) * 2;
    const expectedLen = 6 + infoLen + 2;
    if (body.length !== expectedLen) {
      console.warn(TAG, 'length mismatch', raw);
      return undefined;
    }

    const info = body.substring(6, 6 + infoLen);
    const checksum = body.substring(6 + infoLen, 6 + infoLen + 2);
    const payload = body.substring(0, 6 + infoLen);
    if (numberToHex(getChecksum(payload), 2) !== checksum.toUpperCase()) {
      console.warn(TAG, 'checksum failed', raw);
      return undefined;
    }

    return { vehicleType, cmd, info, raw };
  }

  /**
   * cmd 02 电池电压：2 字节无符号整数，单位 0.01V
   */
  export function parseBatteryVoltage(info: string): number | undefined {
    if (info.length < 4) {
      return undefined;
    }
    const raw = hexToNumber(info.substring(0, 4));
    if (Number.isNaN(raw)) {
      return undefined;
    }
    return raw / 100.0;
  }

  /** 由电压估算电量百分比（默认按 2S 锂电 7.0V~8.4V） */
  export function voltageToPercent(voltage: number, minV: number = 7.0, maxV: number = 8.4): number {
    if (maxV <= minV) {
      return 0;
    }
    const percent = (voltage - minV) / (maxV - minV) * 100;
    return Math.max(0, Math.min(100, Math.round(percent)));
  }

  function hexToNumber(hexString: string): number {
    return parseInt(hexString, 16);
  }

  function numberToHex(num: number, len: number): string {
    let hex = num.toString(16);
    while (hex.length < len) {
      hex = '0' + hex;
    }
    return hex.toUpperCase();
  }

  function getChecksum(data: string): number {
    let sum = 0;
    for (let i = 0; i < data.length; i += 2) {
      sum = (sum + parseInt(data.substring(i, i + 2), 16)) % 256;
    }
    return sum;
  }
}

export interface ExtractResult {
  frames: CarReceiveFrame[];
  remain: string;
}
