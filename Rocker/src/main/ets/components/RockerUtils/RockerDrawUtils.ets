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
    if (this.rockerOptions.getBackgroundStyle) {
      try {
        const img = this.rockerOptions.getBackgroundStyle();
        this.ctx.drawImage(img, 0, 0, this.width, this.height);
        return;
      } catch (e) {
        console.warn(TAG, 'drawImage background failed, use vector fallback');
      }
    }
    this.drawVectorBackground();
  }

  /** 矢量绘制背景轮盘（真机 ImageBitmap 失败时的回退，配色对齐 SVG） */
  private drawVectorBackground(): void {
    const cx = this.width / 2;
    const cy = this.height / 2;
    const r = Math.min(this.width, this.height) / 2;

    const outerGrad = this.ctx.createRadialGradient(cx, cy, r * 0.2, cx, cy, r);
    outerGrad.addColorStop(0, '#5a5768');
    outerGrad.addColorStop(1, '#8e89a6');
    this.ctx.fillStyle = outerGrad;
    this.ctx.beginPath();
    this.ctx.arc(cx, cy, r, 0, Math.PI * 2);
    this.ctx.fill();

    this.ctx.fillStyle = '#838288';
    this.ctx.beginPath();
    this.ctx.arc(cx, cy, r * 0.975, 0, Math.PI * 2);
    this.ctx.fill();

    const arrowLen = r * 0.22;
    const arrowDist = r * 0.62;
    this.ctx.fillStyle = '#FFFFFF';
    this.drawDirectionArrow(cx, cy - arrowDist, arrowLen, 0);
    this.drawDirectionArrow(cx, cy + arrowDist, arrowLen, Math.PI);
    this.drawDirectionArrow(cx - arrowDist, cy, arrowLen, -Math.PI / 2);
    this.drawDirectionArrow(cx + arrowDist, cy, arrowLen, Math.PI / 2);
  }

  private drawDirectionArrow(cx: number, cy: number, size: number, angle: number): void {
    this.ctx.save();
    this.ctx.translate(cx, cy);
    this.ctx.rotate(angle);
    this.ctx.beginPath();
    this.ctx.moveTo(0, -size * 0.55);
    this.ctx.lineTo(size * 0.45, size * 0.35);
    this.ctx.lineTo(-size * 0.45, size * 0.35);
    this.ctx.closePath();
    this.ctx.fill();
    this.ctx.restore();
  }

  /**
   * 绘制手指
   */
  private drawRule() {
    let tiltR: number = this.FingerRadius;
    tiltR = this.FingerRadius < 1 ? this.width / 2 * tiltR : tiltR;

    let x = MathUtils.mapValue(this.tiltX,
      0, this.width,
      0 + tiltR, this.width - tiltR)
    let y = MathUtils.mapValue(this.tiltY,
      0, this.height,
      0 + tiltR, this.height - tiltR)

    if (this.rockerOptions.getTiltStyle) {
      try {
        this.ctx.drawImage(this.rockerOptions.getTiltStyle(),
          x - tiltR, y - tiltR,
          tiltR * 2, tiltR * 2,
        )
        return;
      } catch (e) {
        console.warn(TAG, 'drawImage knob failed, use vector fallback');
      }
    }
    this.drawVectorKnob(x, y, tiltR);
  }

  /** 矢量绘制摇杆头（配色对齐 remote.svg） */
  private drawVectorKnob(x: number, y: number, tiltR: number): void {
    const knobGrad = this.ctx.createRadialGradient(
      x - tiltR * 0.2, y - tiltR * 0.2, tiltR * 0.1,
      x, y, tiltR
    );
    knobGrad.addColorStop(0, '#eceaed');
    knobGrad.addColorStop(1, '#b8b5bc');
    this.ctx.fillStyle = knobGrad;
    this.ctx.beginPath();
    this.ctx.arc(x, y, tiltR, 0, Math.PI * 2);
    this.ctx.fill();

    this.ctx.strokeStyle = '#9a979f';
    this.ctx.lineWidth = 2;
    this.ctx.beginPath();
    this.ctx.arc(x, y, tiltR * 0.92, 0, Math.PI * 2);
    this.ctx.stroke();

    this.ctx.fillStyle = '#d5d3d6';
    this.ctx.beginPath();
    this.ctx.arc(x, y, tiltR * 0.35, 0, Math.PI * 2);
    this.ctx.fill();
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