import { DualCarStatus, DualCarStatusManager } from '../tcp/DualCarStatusManager'
import { AppRadius } from '../styles/styles'
import { StyledText, TextVariant } from '../styles/Typography'

/**
 * 双车状态条
 */
@Component
export struct DualCarStatusBar {
  @State statusText: string = DualCarStatusManager.getStatusText()
  @State isWarning: boolean = false
  @State visible: boolean = DualCarStatusManager.dualModeEnabled

  aboutToAppear(): void {
    this.visible = DualCarStatusManager.dualModeEnabled
    this.refresh(DualCarStatusManager.getStatus())
    DualCarStatusManager.subscribe((status: DualCarStatus) => {
      this.refresh(status)
    })
  }

  private refresh(status: DualCarStatus): void {
    this.visible = DualCarStatusManager.dualModeEnabled
    this.statusText = DualCarStatusManager.getStatusText()
    this.isWarning = DualCarStatusManager.dualModeEnabled &&
      !(status.mode === 'dual' && status.slaveOnline)
  }

  build() {
    if (this.visible) {
      Row() {
        StyledText({
          content: this.statusText,
          variant: TextVariant.Caption,
          hasCustomColor: true,
          customColor: this.isWarning ?
            $r('app.color.button_text_on_primary') : $r('app.color.text')
        })
      }
      .width('100%')
      .padding({ left: '14vp', right: '14vp', top: '8vp', bottom: '8vp' })
      .backgroundColor(this.isWarning ?
        $r('app.color.warning_background') : $r('app.color.button_select_background'))
      .borderRadius(AppRadius.MD)
    }
  }
}
