/**
 * 连接接收工具
 */
// import { DeviceModel } from '../model/DeviceModel';
// import { NetInfoModel } from '../model/NetInfoModel';
// import { TcpReceiveDeviceModel, TcpReceiveInfoModel } from './TCPModel';

const TAG = "TCPClientReceiveUtils";

export class TCPClientReceiveUtils {
  // @todo 这个里面写的是接收到数据后的响应
  public static receiveMessage() {
    //   // 如果拿到的是空字符串那么结束判断
    //   if (!message) return;
    //   console.log(TAG, "receiveMessage()", "message", JSON.stringify(message))
    //
    //   let info = JSON.parse(message) as TcpReceiveInfoModel;
    //
    //   let devices: TcpReceiveDeviceModel[] = info.data;
    //
    //   // 比较粗暴的for循环迭代方案，如果有序有性能瓶颈可以用map提高性能。
    //   for (let index = 0; index < devices.length; index++) {
    //     const device = devices[index];
    //
    //     for (let index = 0; index < deviceModels.length; index++) {
    //       const deviceModel = deviceModels[index];
    //       // 如果数据的唯一标识一样
    //       if (deviceModel.DeviceMAC == device.key) {
    //         // 数据更新
    //         InfoUpDeviceModel(device, deviceModel);
    //       }
    //     }
    //   }
    //
  }
}


// 验证数据



