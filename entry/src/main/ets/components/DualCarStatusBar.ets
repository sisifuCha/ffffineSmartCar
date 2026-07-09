import { DualCarStatus, DualCarStatusManager } from '../tcp/DualCarStatusManager'

/**
 * 双车状态条：显示双车同步 / 降级主车单控
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
        Text(this.statusText)
          .fontSize('14fp')
          .fontColor(this.isWarning ? Color.White : $r('app.color.button_text'))
      }
      .width('100%')
      .padding({ left: '12vp', right: '12vp', top: '6vp', bottom: '6vp' })
      .backgroundColor(this.isWarning ? '#CC8B0000' : $r('app.color.button_background'))
      .borderRadius('6vp')
    }
  }
}
