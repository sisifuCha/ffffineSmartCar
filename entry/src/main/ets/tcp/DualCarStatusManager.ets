/**
 * 双车编排状态管理：解析主车推送的 @STATUS 帧
 */

export type DualCarMode = 'dual' | 'master_only'

export interface DualCarStatus {
  mode: DualCarMode
  slaveOnline: boolean
  lastAckMs: number
  seq: number
}

const STATUS_PREFIX = '@STATUS'
const CONFIG_PREFIX = '@CONFIG'

export class DualCarStatusManager {
  private static status: DualCarStatus = {
    mode: 'master_only',
    slaveOnline: false,
    lastAckMs: -1,
    seq: 0
  }

  private static listeners: Array<(status: DualCarStatus) => void> = []

  static getStatus(): DualCarStatus {
    return DualCarStatusManager.status
  }

  static getStatusText(): string {
    const s = DualCarStatusManager.status
    if (!DualCarStatusManager.dualModeEnabled) {
      return '单车模式'
    }
    if (s.mode === 'dual' && s.slaveOnline) {
      return `双车同步中 (ACK ${s.lastAckMs}ms)`
    }
    return '从车离线 · 主车单控'
  }

  static dualModeEnabled: boolean = false

  static subscribe(listener: (status: DualCarStatus) => void): void {
    DualCarStatusManager.listeners.push(listener)
  }

  static dispatch(message: string): boolean {
    const frames = DualCarStatusManager.splitFrames(message)
    let handled = false
    for (const frame of frames) {
      if (DualCarStatusManager.tryParseStatus(frame)) {
        handled = true
      }
    }
    return handled
  }

  private static splitFrames(message: string): string[] {
    const frames: string[] = []
    let start = 0
    while (start < message.length) {
      const statusIdx = message.indexOf(STATUS_PREFIX, start)
      const configIdx = message.indexOf(CONFIG_PREFIX, start)
      const controlIdx = message.indexOf('$', start)

      let nextIdx = -1
      if (statusIdx >= 0) {
        nextIdx = statusIdx
      }
      if (configIdx >= 0 && (nextIdx < 0 || configIdx < nextIdx)) {
        nextIdx = configIdx
      }
      if (controlIdx >= 0 && (nextIdx < 0 || controlIdx < nextIdx)) {
        nextIdx = controlIdx
      }
      if (nextIdx < 0) {
        break
      }

      const endIdx = message.indexOf('#', nextIdx)
      if (endIdx < 0) {
        break
      }
      frames.push(message.substring(nextIdx, endIdx + 1))
      start = endIdx + 1
    }
    return frames
  }

  private static tryParseStatus(frame: string): boolean {
    if (!frame.startsWith(STATUS_PREFIX) || !frame.endsWith('#')) {
      return false
    }
    const jsonText = frame.substring(STATUS_PREFIX.length, frame.length - 1)
    try {
      const data = JSON.parse(jsonText) as Record<string, string | number | boolean>
      const mode = `${data['mode']}` === 'dual' ? 'dual' : 'master_only'
      DualCarStatusManager.status = {
        mode: mode,
        slaveOnline: Boolean(data['slaveOnline']),
        lastAckMs: Number(data['lastAckMs']),
        seq: Number(data['seq'])
      }
      DualCarStatusManager.notify()
      return true
    } catch (e) {
      console.error('DualCarStatusManager parse error', JSON.stringify(e))
      return false
    }
  }

  private static notify(): void {
    for (const listener of DualCarStatusManager.listeners) {
      listener(DualCarStatusManager.status)
    }
  }

  static buildConfigMessage(dualMode: boolean, slaveIp: string, slavePort: number): string {
    const payload = JSON.stringify({
      dualMode: dualMode,
      slaveIp: slaveIp,
      slavePort: slavePort
    })
    return `${CONFIG_PREFIX}${payload}#`
  }

  static reset(): void {
    DualCarStatusManager.status = {
      mode: 'master_only',
      slaveOnline: false,
      lastAckMs: -1,
      seq: 0
    }
    DualCarStatusManager.notify()
  }
}
