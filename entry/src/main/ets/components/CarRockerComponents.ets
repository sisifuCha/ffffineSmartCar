import { carApi } from '../CarUtill/CarApi'
import { CarEncode } from '../CarUtill/CarEncode';

import { RockerComponent, RockerOptions } from "rocker"

let TAG = 'anran0';


/**
 * 按键控制UI组件
 */
@Component
struct CarRockerComponents {
  tiltStyle = new ImageBitmap("img/remote.svg");
  backgroundStyle = new ImageBitmap("img/remote_background.svg");
  private lastSendTime: number = 0;
  private readonly sendIntervalMs: number = 50;

  build() {
    RockerComponent({
      rockerOptions: new RockerOptions({
        tiltWidth: 0.6,
        getTiltStyle: (): ImageBitmap => this.tiltStyle,
        getBackgroundStyle: (): ImageBitmap => this.backgroundStyle,
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
  }
}

export { CarRockerComponents }