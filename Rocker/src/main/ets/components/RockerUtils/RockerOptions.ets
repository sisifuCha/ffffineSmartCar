export type GetImageBitmap = () => ImageBitmap

/**
 * 遥感控制
 */
@Observed
export class RockerOptions implements iRockerOptions {
  /**宽度*/
  width?: number;
  /**高度*/
  height?: number;
  /**手指宽度*/
  tiltWidth?: number;
  /** 画布宽度 */
  canveWidth?: number;
  /** 画布高度 */
  canveHeight?: number;
  /** 手指样式 */
  getTiltStyle?: GetImageBitmap;
  /** 背景样式 */
  getBackgroundStyle?: GetImageBitmap;
  /**
   *手指调用回调
   * @param tiltX -100~100 手指触摸X位置
   * @param tiltY -100~100 手指触Y位置
   * @param event 手指触摸事件
   */
  tiltEvent?: (tiltX: number, tiltY: number, event?: TouchEvent) => void

  constructor(i?: iRockerOptions) {
    if (!i) return;
    this.width = i.width;
    this.height = i.height;
    this.tiltWidth = i.tiltWidth;
    this.canveWidth = i.canveWidth;
    this.canveHeight = i.canveHeight;
    this.getTiltStyle = i.getTiltStyle;
    this.getBackgroundStyle = i.getBackgroundStyle;
    this.tiltEvent = i.tiltEvent;
  }
}

export interface iRockerOptions {
  /**宽度*/
  width?: number;

  /**高度*/
  height?: number;

  /**手指宽度*/
  tiltWidth?: number;

  /** 画布宽度 */
  canveWidth?: number;

  /** 画布高度 */
  canveHeight?: number;

  /** 手指样式 */
  getTiltStyle?: GetImageBitmap;

  /** 背景样式 */
  getBackgroundStyle?: GetImageBitmap;

  /**
   *手指调用回调
   * @param tiltX -100~100 手指触摸X位置
   * @param tiltY -100~100 手指触Y位置
   * @param event 手指触摸事件
   */
  tiltEvent?: (tiltX: number, tiltY: number, event?: TouchEvent) => void
}