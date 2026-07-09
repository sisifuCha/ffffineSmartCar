
/**
 * 小车运动方向
 */
export enum CarDirection {
  // 0停车，=1前进，=2后退，=3左平移，=4右平移，=5左旋转，=6右旋转，=7刹车停止。
  /**停车*/
  Stop = 0,
  /**前进*/
  Front = 1,
  /**后退*/
  After = 2,
  /**左移动*/
  Left = 3,
  /**右移动*/
  Right = 4,
  /**左移动*/
  LeftRotate = 5,
  /**右移动*/
  RightRotate = 6,
  /**停车*/
  Brake = 7
}