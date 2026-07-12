import { CarStatusStore } from './CarStatusStore';

/** 全局会话：连接态 / 仅浏览模式 */
export class AppSession {
  static readonly KEY_VIEW_ONLY = 'app_view_only';
  static readonly KEY_TCP_CONNECTED = 'app_tcp_connected';

  static init(): void {
    AppStorage.setOrCreate(AppSession.KEY_VIEW_ONLY, false);
    AppStorage.setOrCreate(AppSession.KEY_TCP_CONNECTED, false);
  }

  static isViewOnly(): boolean {
    return AppStorage.get<boolean>(AppSession.KEY_VIEW_ONLY) ?? false;
  }

  static isTcpConnected(): boolean {
    return AppStorage.get<boolean>(AppSession.KEY_TCP_CONNECTED) ?? false;
  }

  static enterViewOnly(): void {
    AppStorage.set(AppSession.KEY_VIEW_ONLY, true);
    AppStorage.set(AppSession.KEY_TCP_CONNECTED, false);
    CarStatusStore.setConnected(false);
  }

  static enterConnected(): void {
    AppStorage.set(AppSession.KEY_VIEW_ONLY, false);
    AppStorage.set(AppSession.KEY_TCP_CONNECTED, true);
  }

  static markDisconnected(): void {
    AppStorage.set(AppSession.KEY_TCP_CONNECTED, false);
    CarStatusStore.setConnected(false);
  }

  /** 退出浏览模式，回到连接页前调用 */
  static exitViewOnly(): void {
    AppStorage.set(AppSession.KEY_VIEW_ONLY, false);
  }
}
