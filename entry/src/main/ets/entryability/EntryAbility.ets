import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import hilog from '@ohos.hilog';
import UIAbility from '@ohos.app.ability.UIAbility';
import Want from '@ohos.app.ability.Want';
import window from '@ohos.window';
import { ScreenUtils } from "../utils/ScreenUtils"
import { TCPClientManager } from '../tcp/TCPClientManager';
import { TCPClientSendUtils } from '../tcp/TCPClientSendUtils';
import { PreferencesUtils } from '../utils/PreferencesUtils';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onCreate');

    PreferencesUtils.getInstance().init(this.context).then(() => {
      hilog.info(0x0000, 'testTag', 'Preferences initialized');
    });
  }

  onDestroy(): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/NetworkSettings', (err) => {
    // windowStage.loadContent('pages/MecanumWheel', (err) => {
    // windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err) ?? '');
        return;
      }
      hilog.info(0x0000, 'testTag', 'Succeeded in loading the content.');
    });

    // 设置应用为横屏
    ScreenUtils.setLandscape(this.context)
    // 设置屏幕常量
    ScreenUtils.keepScreenOn(this.context, true)
    // 设置标题栏不可见
    // ScreenUtils.setSystemBarEnable_api9(this.context)
    ScreenUtils.setSystemBarEnable_api10(windowStage)

  }


  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
