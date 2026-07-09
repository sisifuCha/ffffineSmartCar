import { TCPClientManager } from './TCPClientManager';

const TAG = "TCPClientPantUtils";

/**
 * TCP发送工具
 */
export class TCPClientSendUtils {
  /**私有静态实例，懒汉式单例*/
  private static instance: TCPClientSendUtils | undefined = undefined;

  /**私有构造方法，防止外部直接实例化*/
  private constructor() {
  }

  /**提供一个公共的静态方法返回实例对象*/
  public static getInstance(): TCPClientSendUtils {
    // 如果对象单例不存在那么构建对象
    if (!TCPClientSendUtils.instance)
      TCPClientSendUtils.instance = new TCPClientSendUtils();
    return TCPClientSendUtils.instance;
  }


  /**
   * 初始化心跳包发送函数
   */
  public init() {
    setInterval(async () => {
      // 心跳增长
      // this._pant++
      // // 心跳包对象
      // let p: TCPSendTypeModel = newPant(this.pant)
      // // 解析心跳包对象成为json形式
      // let pant: string = JSON.stringify(p)
      // let pant: string = "hello"
      // 发送数据
      // let state: boolean = await TCPClientManager.getInstance().sendMessage(pant + '\n')
      // // 如果发送失败，那么重置心跳包的状态
      // if (state == false) this._pant = -1;
      //   5秒发一次数据
    }, 5000)
  }

  /**
   * 心跳数 ,只有在发送心跳包的时候心跳数才会变化
   */
  private _pant: number = -1;

  public get pant(): number {
    return this._pant % 8;
  }


  /**
   * 控制设备
   */
  // public async ctrl(model: TCPSendCtrlModel) {
  //   let v = newCtrl(this.pant, model)
  //   let m = JSON.stringify(v);
  //   let state: boolean = await TCPClientManager.getInstance().sendMessage(m + '\n')
  //   // 返回是否成功发送至网关的状态
  //   return state;
  // }
}

