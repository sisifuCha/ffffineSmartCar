import { carApi } from '../CarUtill/CarApi'
import { CarEncode } from '../CarUtill/CarEncode';

import { RockerComponent, RockerOptions } from "rocker"

let TAG = 'anran0';


/**
 * 按键控制UI组件
 */
@Component
struct CarRockerComponents {
  // 摇杆的手指的样式
  tiltStyle = new ImageBitmap("img/remote.svg");
  // 摇杆的背景样式
  backgroundStyle = new ImageBitmap("img/remote_background.svg");

  /**
   * 构建并渲染摇杆控制组件
   * 此方法定义了摇杆组件的外观和行为。
   * 它通过配置RockerComponent的参数来设置摇杆的宽度、样式、背景以及倾斜事件的处理。
   */
  build() {
    RockerComponent({
      // 摇杆的选项配置
      rockerOptions: new RockerOptions({
        // 摇杆的宽度，这里以屏幕宽度的百分比表示
        tiltWidth: 0.6,
        // 获取摇杆倾斜时的样式
        getTiltStyle: (): ImageBitmap => this.tiltStyle,
        // 获取摇杆的背景样式
        getBackgroundStyle: (): ImageBitmap => this.backgroundStyle,
        // 摇杆倾斜事件处理函数
        // 当摇杆倾斜时，此函数被调用，并接收倾斜的X和Y方向值，以及可能的TouchEvent对象
        tiltEvent: (tiltX: number, tiltY: number, event?: TouchEvent): void => {
          // 使用小车API发送控制指令
          // CarEncode.CtrlCarEncode是一个函数，用于将倾斜的X和Y值编码为小车可识别的控制指令
          carApi.send(CarEncode.CtrlCarEncode(tiltX, tiltY));
        }
      })
    })
  }
}

export { CarRockerComponents }