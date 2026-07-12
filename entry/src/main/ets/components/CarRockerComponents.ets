import { carApi } from '../CarUtill/CarApi'
import { CarEncode } from '../CarUtill/CarEncode';
import { RockerComponent, RockerOptions } from "rocker"

/**
 * 摇杆控制 UI 组件
 * 真机上 ImageBitmap 绘制 SVG 会失败，由 Rocker 模块内矢量绘制回退显示轮盘
 */
@Component
struct CarRockerComponents {
  private lastSendTime: number = 0;
  private readonly sendIntervalMs: number = 50;

  build() {
    RockerComponent({
      rockerOptions: new RockerOptions({
        tiltWidth: 0.38,
        tiltEvent: (tiltX: number, tiltY: number, event?: TouchEvent): void => {
          const now = Date.now();
          if (now - this.lastSendTime < this.sendIntervalMs) {
            return;
          }
          this.lastSendTime = now;
          carApi.send(CarEncode.CtrlCarEncode(tiltX, tiltY));
        }
      })
    })
      .width('100%')
      .height('100%')
  }
}

export { CarRockerComponents }
