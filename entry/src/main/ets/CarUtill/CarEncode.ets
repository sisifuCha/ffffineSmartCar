import { MyUtils } from '../utils/MyUtils';
import { CarDirection } from './CarEnum';

let TAG = "CarEncode"
let isDebug = MyUtils.isDebug;


export namespace CarEncode {


  /**
   * 获取电池电压
   */
  export function GetBatteryVoltageEncode(): string {
    return BaseEncode('02');
  }

  /**
   * 开始循迹
   * @returns
   */
  export function TrackingOpenEncode(): string {
    return BaseEncode('63');
  }

  /**
   * 关闭循迹
   * @returns
   */
  export function TrackingCloseEncode(): string {
    return BaseEncode('64');
  }

  /**
   * 拍摄图片
   * @returns
   */
  export function TakePhotosEncode(): string {
    return BaseEncode('60');
  }


  /**
   * 开始录像
   * @returns
   */
  export function StartRecordingEncode(): string {
    return BaseEncode('61');
  }

  /**
   * 结束录像
   * @returns
   */
  export function CloselRecordingEncode(): string {
    return BaseEncode('62');
  }

  /**
   * 车辆控制编码
   * @param speed_x -100 ~ 100
   * @param speed_y -100 ~ 100
   * @returns
   */
  export function CtrlCarEncode(speed_x: number, speed_y: number): string {
    // 四舍五入
    let send_x = speed_x = Math.round(speed_x)
    let send_y = speed_y = Math.round(speed_y)

    // 调试模式下输出信息
    if (isDebug) console.log(TAG, 'CtrlCarEncode', `speed_x = ${speed_x}`, `speed_y = ${speed_y}`);


    if (send_x < 0) send_x += 256
    if (send_y < 0) send_y += 256

    // 调试模式下输出信息
    if (isDebug)
      console.log(TAG, 'CtrlCarEncode',
        `speed_x = ${speed_x}`, `speed_y = ${speed_y}`,
        `sendx = ${send_x}`, `sendy = ${send_y}`,
      );


    return BaseEncode('10',
      numberToHex(send_x, 2) +
      numberToHex(send_y, 2)
    );
  }

  /**
   *按钮车辆控制
   * @param d
   * @returns
   */
  export function ButtonCarEncode(d: CarDirection): string {
    return BaseEncode('15',
      numberToHex(d, 2)
    );
  }

  /**
   *四轮单独控制
   * @param d
   * @returns
   */
  export function UpSpeedCarEncode(l1: number, l2: number, r1: number, r2: number): string {
    let format = (x: number) => {
      x = Math.round(x); // 四舍五入
      if (x < 0) x += 256 // 如果是负数那么格式化成正数
      return x;
    }

    // 格式化字符串
    l1 = format(l1);
    l2 = format(l2);
    r1 = format(r1);
    r2 = format(r2);

    // 返回编码信息
    return BaseEncode('21',
      numberToHex(l1, 2),
      numberToHex(l2, 2),
      numberToHex(r1, 2),
      numberToHex(r2, 2),
    );
  }


  /**
   * 通用基础编码能力
   * @param type
   * @param data
   */
  function BaseEncode(type: string, ...datas: string[]) {

    let info: string = datas.join('')

    // 8为基础数据长度
    let size = numberToHex(info.length + 2, 2);

    // 数据拼接
    let code = '01' + //车辆类型
      type + // 命令标记
      size + // 数据长度
      info // 数据主体

    code += numberToHex(getCheckChecksum(code), 2);

    //$ 车辆类型  数据 #
    // 添加开始结束符
    code = `$${code}#`

    // 调试模式下输出信息
    if (isDebug) console.log(TAG, 'BaseEncode', code);

    return code;
  }

  /**数字转十六进制*/
  function numberToHex(num: number, len: number) {
    let hex = num.toString(16);
    while (hex.length < len)
      hex = '0' + hex;
    return hex.toUpperCase(); // 如果需要小写，去掉.toUpperCase()
  }

  /**
   * 数据校验运算
   * @param data
   * @returns
   */
  function getCheckChecksum(data: string) {
    console.log("getCheckChecksum", data)
    // 初始化校验和变量
    let dataSize = data.length;
    let calculatedChecksum = 0;

    // 计算校验和（跳过最后两个字符）
    for (let i = 0; i < dataSize; i += 2) {
      // 每次处理两个字符（一个字节）
      const byte = parseInt(data.substr(i, 2), 16);
      calculatedChecksum = (calculatedChecksum + byte) % 256;
    }
    // 返回校验值状态
    return calculatedChecksum
  }

  /**
   * 十六进制转数字
   * @param hexString
   * @returns
   */
  function hexToNumber(hexString: string) {
    let number = parseInt(hexString, 16);
    return number;
  }
}

