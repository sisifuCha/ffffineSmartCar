import { MathUtils } from '../utils/MathUtils';
import { RockerOptions } from './RockerOptions';

const TAG = 'CarRockerDrawUtils';
const isDebug = false;

class RockerDrawUtils {
  /**摇杆绘制选项*/
  rockerOptions: RockerOptions = new RockerOptions();

  //构造函数
  constructor(ctx: CanvasRenderingContext2D, rockerOptions?: RockerOptions) {
    this.ctx = ctx;
    if (rockerOptions) {
      this.rockerOptions = rockerOptions;
    }

  }

  /**
   * 初始化
   * @param rockerOptions
   */
  public init(rockerOptions?: RockerOptions) {
    if (rockerOptions) {
      this.rockerOptions = rockerOptions;
    }
  }

  // ---------------常量------------------------------


  // ---------------对象------------------------------
  /**画布*/
  private ctx: CanvasRenderingContext2D
  // ---------------变量------------------------------
  /**手指触摸的X轴*/
  private _tiltX: number = 0
  /**手指触摸的Y轴*/
  private _tiltY: number = 0
  /**屏幕绘制的宽度*/
  private _width: number = 0;
  /**屏幕绘制的高度*/
  private _height: number = 0;
  /** 绘制事件（总）*/
  public myOnReadyEvent = () => {

    // 1.初始化数据

    // 2.清除画布上的内容
    this.clearCanvas();

    // 3.绘制背景图像
    this.drawBackground();

    // 4.绘制手指图像
    this.drawRule();


    console.log(TAG, `myOnReadyEvent End`)
  }

  /**
   * 清除画布内容
   * @param w
   * @param h
   */
  private clearCanvas() {

    // 如果reset 不可用,那么使用clearRect清除画布
    this.ctx.clearRect(0, 0, this.width, this.height);
  }

  /**
   * 绘制背景
   */
  private drawBackground() {

    // @todo 这段代码在api9 HarmonyOS4.0 （Mate50）下验证失败
    if (this.rockerOptions.getBackgroundStyle) {
      //  如果自定义图形,那么使用自定义图形进行绘制
      let img = this.rockerOptions.getBackgroundStyle();
      this.ctx.drawImage(img, 0, 0, this.width, this.height);
      return;
    }

    // 如果没有自定义图形,那么用默认圆圈填充
    this.ctx.strokeStyle = '#000';
    let rule2D: Path2D = new Path2D();
    let w = this.width, h = this.height; //组件宽高
    rule2D.arc(w / 2, h / 2, w / 2, 0, 360);
    this.ctx.stroke(rule2D);
  }

  /**
   * 绘制手指
   */
  private drawRule() {
    // 手指半径
    let tiltR: number = this.FingerRadius;
    tiltR = this.FingerRadius < 1 ? this.width / 2 * tiltR : tiltR;

    // 手指绘制映射,避免手指绘制不完全
    let x = MathUtils.mapValue(this.tiltX,
      0, this.width,
      0 + tiltR, this.width - tiltR)
    let y = MathUtils.mapValue(this.tiltY,
      0, this.height,
      0 + tiltR, this.width - tiltR)

    // @todo 这段代码在api9 HarmonyOS4.0（Mate50）下验证失败
    if (this.rockerOptions.getTiltStyle) {
      // 如果提供了绘制图案，那么绘制
      this.ctx.drawImage(this.rockerOptions.getTiltStyle(),
        x - tiltR, y - tiltR,
        tiltR * 2, tiltR * 2,
      )
      return;
    }

    // 如果没有自定义图形那么进行绘制
    this.ctx.fillStyle = '#999';
    let rule2D: Path2D = new Path2D();
    rule2D.arc(x, y, tiltR, 0, 360);
    this.ctx.fill(rule2D);

  }

  // ---------------------------getder---------------------------

  /**手指绘制大小半径*/
  public get FingerRadius(): number {
    // 如果配置了手指大小,那么将使用配置大小
    if (this.rockerOptions.tiltWidth) {
      return this.rockerOptions.tiltWidth;
    }
    // 如果没有配置手指大小,那么将使用默认大小
    return 25;
  }

  public get width(): number {
    return this._width;
  }

  public get height(): number {
    return this._height;
  }

  public get tiltX(): number {
    // 如果左侧越界，那么返回边界
    if (this._tiltX < 0) {
      return 0
    }
    // 如果右侧越界，那么返回边界
    if (this._tiltX > this.width) {
      return this.width
    }
    // 正常返回
    return this._tiltX
  }

  public get tiltY(): number {

    // 如果左侧越界，那么返回边界
    if (this._tiltY < 0) {
      return 0;
    }
    // 如果右侧越界，那么返回边界
    if (this._tiltY > this.height) {
      return this.height;
    }
    // 正常返回
    return this._tiltY
  }

  // ---------------------------setder---------------------------
  /**
   * 初始化手指位置
   * @param tiltX 手指的x轴
   * @param tiltY 手指的y轴
   */
  public setTiltXY(tiltX: number, tiltY: number) {
    this._tiltX = tiltX;
    this._tiltY = tiltY;

    if (isDebug) {
      console.log(TAG, "setTiltXY", "tiltY=", this.tiltY, "tiltX=", this.tiltX)
    }

  }

  /**
   * 设置绘制的大小
   * @param width 绘制的宽度
   * @param height 绘制的高度
   */
  public setSize(width: number, height: number) {
    this._height = height;
    this._width = width;
  }
}

export { RockerDrawUtils }