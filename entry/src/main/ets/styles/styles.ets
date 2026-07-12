interface ButtonShadowStyle {
  radius: number
  offsetY: number
  offsetX: number
  color: string
}

export const ButtonShadow: ButtonShadowStyle = {
  radius: 8,
  offsetY: 2,
  offsetX: 0,
  color: '#14000000'
}

export const CardShadow: ButtonShadowStyle = {
  radius: 16,
  offsetY: 4,
  offsetX: 0,
  color: '#0A000000'
}

/** 全局圆角规范 */
export class AppRadius {
  static readonly SM: string = '10vp';
  static readonly MD: string = '14vp';
  static readonly LG: string = '20vp';
  static readonly XL: string = '24vp';
}
