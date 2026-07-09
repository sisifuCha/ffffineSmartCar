class MathUtils {
  /**
   * 数据映射
   * @param a 原始数据
   * @param al 原始数据的区间左侧
   * @param ar 原始数据的区间右侧
   * @param bl 新数据的区间左侧
   * @param br 新数据的区间右侧
   * @returns 新数据
   */
  public static mapValue(a: number, al: number, ar: number, bl: number, br: number) {
    // 确保a1不等于a2，避免除以零
    if (al === ar) {
      console.error(`al=${al} ar=${ar},al and ar cannot be equal`);
      return 0;
    }

    // 计算映射后的值
    let result = bl + ((a - al) * (br - bl)) / (ar - al);

    // 根据需要，可以对结果进行四舍五入、取整或保留特定小数位数
    // 例如：四舍五入到小数点后两位
    // result = Math.round((result + Number.EPSILON) * 100) / 100;

    return result;
  }
}


export { MathUtils }