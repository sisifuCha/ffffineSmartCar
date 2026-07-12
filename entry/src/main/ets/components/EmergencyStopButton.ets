import promptAction from '@ohos.promptAction';
import { carApi } from '../CarUtill/CarApi';
import { AppRadius, ButtonShadow } from '../styles/styles';
import { AppFont } from '../styles/Typography';

/** 急停：刹车 + 摇杆归零 + 四轮速度清零 */
@Component
export struct EmergencyStopButton {
  @Prop fullWidth: boolean = true;
  onStopped: () => void = () => {
  };

  build() {
    Button('急停')
      .width(this.fullWidth ? '100%' : '120vp')
      .height('44vp')
      .fontSize('16fp')
      .fontFamily(AppFont.FAMILY)
      .fontWeight(FontWeight.Medium)
      .fontColor('#FFFFFF')
      .backgroundColor('#C54B4B')
      .borderRadius(AppRadius.MD)
      .shadow(ButtonShadow)
      .onClick(() => {
        carApi.emergencyStop();
        this.onStopped();
        promptAction.showToast({ message: '已急停' });
      })
  }
}
