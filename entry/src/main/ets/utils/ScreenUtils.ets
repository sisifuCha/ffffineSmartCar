import window from '@ohos.window'
import common from '@ohos.app.ability.common'
import { BusinessError } from '@ohos.base'

export namespace ScreenUtils {

  export const SAFE_AREA_TOP_KEY: string = 'safeAreaTopPx';

  /**
   * 读取系统状态栏避让高度，避免内容与状态栏/挖孔重叠
   */
  export function initSafeArea(windowStage: window.WindowStage): void {
    const windowClass: window.Window = windowStage.getMainWindowSync();
    const applyAvoidArea = (): void => {
      const area = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      AppStorage.setOrCreate(ScreenUtils.SAFE_AREA_TOP_KEY, area.topRect.height);
    };
    applyAvoidArea();
    windowClass.on('avoidAreaChange', () => {
      applyAvoidArea();
    });
  }

  /**
   * 保持屏幕常量
   * @param status
   */
  export async function keepScreenOn(ctx: common.BaseContext, status: boolean) {
    // let context = getContext(this) as common.BaseContext
    let windowClass = await window.getLastWindow(ctx) //获取窗口实例
    let isScreenOn = await windowClass.getWindowProperties().isKeepScreenOn //查看屏幕常亮状态
    if (!isScreenOn) {
      await windowClass.setWindowKeepScreenOn(status) //设置窗口常亮或取消
    }
    console.info("屏幕常亮状态： " + isScreenOn)
  }

  /**
   * 设置导航栏，状态栏不可见，在api9以后不能使用
   */
  export async function setSystemBarEnable_api9(ctx: common.BaseContext) {
    let windowClass = await window.getLastWindow(ctx)
    await windowClass.setWindowSystemBarEnable([])
  }


  /**
   * 设置导航栏，状态栏不可见，在api9以后不能使用
   */
  export async function setSystemBarEnable_api10(windowStage: window.WindowStage) {
    let windowClass: window.Window = windowStage.getMainWindowSync(); // 获取应用主窗口
    // 1. 设置窗口全屏
    let isLayoutFullScreen = true;
    windowClass.setWindowLayoutFullScreen(isLayoutFullScreen)
      .then(() => {
        console.info('Succeeded in setting the window layout to full-screen mode.');
      })// .catch((err: BusinessError) => {
      .catch((err: BusinessError) => {
        console.error('Failed to set the window layout to full-screen mode. Cause:' + JSON.stringify(err));
      });
  }


  /**
   * 将应用设置为竖屏
   */
  export function setPortrait(ctx: common.BaseContext) {
    let promise = window.getLastWindow(ctx);
    promise.then((data) => {
      let orientation = window.Orientation.PORTRAIT;
      data.setPreferredOrientation(orientation, (err) => {
      });
    })
  }


}