/** 字体常量（兼容各版本 ArkTS，不使用跨文件 @Extend） */
export class AppFont {
  static readonly FAMILY: string = 'HarmonyOS Sans SC';
  static readonly FAMILY_EN: string = 'HarmonyOS Sans';
}

/** 文字样式变体 */
export enum TextVariant {
  Title = 0,
  Heading = 1,
  Subtitle = 2,
  Body = 3,
  Label = 4,
  Caption = 5,
  NavLabel = 6,
  Metric = 7,
  Action = 8,
  Status = 9
}

/**
 * 统一文字组件：替代 .appTitle() 等 @Extend 链式写法
 * 在当前 DevEco / API 版本下跨文件 @Extend 不可用，故用组件封装
 */
@Component
export struct StyledText {
  @Prop content: string = '';
  @Prop variant: TextVariant = TextVariant.Body;
  @Prop textAlign: TextAlign = TextAlign.Start;
  @Prop hasCustomColor: boolean = false;
  @Prop customColor: ResourceColor = '#3D3D3A';
  @Prop maxLines: number = 0;

  build() {
    Text(this.content)
      .fontFamily(this.pickFamily())
      .fontSize(this.pickSize())
      .fontWeight(this.pickWeight())
      .fontColor(this.pickColor())
      .letterSpacing(this.pickLetterSpacing())
      .lineHeight(this.pickLineHeight())
      .textAlign(this.textAlign)
      .maxLines(this.maxLines)
  }

  private pickFamily(): string {
    if (this.variant === TextVariant.Metric) {
      return AppFont.FAMILY_EN;
    }
    return AppFont.FAMILY;
  }

  private pickSize(): string {
    switch (this.variant) {
      case TextVariant.Title:
        return '26fp';
      case TextVariant.Heading:
        return '18fp';
      case TextVariant.Subtitle:
        return '14fp';
      case TextVariant.Body:
        return '15fp';
      case TextVariant.Label:
        return '13fp';
      case TextVariant.Caption:
        return '12fp';
      case TextVariant.NavLabel:
        return '10fp';
      case TextVariant.Metric:
        return '30fp';
      case TextVariant.Action:
        return '14fp';
      case TextVariant.Status:
        return '13fp';
      default:
        return '15fp';
    }
  }

  private pickWeight(): FontWeight {
    switch (this.variant) {
      case TextVariant.Title:
      case TextVariant.Heading:
      case TextVariant.Metric:
      case TextVariant.Action:
        return FontWeight.Medium;
      default:
        return FontWeight.Normal;
    }
  }

  private pickColor(): ResourceColor {
    if (this.hasCustomColor) {
      return this.customColor;
    }
    switch (this.variant) {
      case TextVariant.Subtitle:
      case TextVariant.Label:
      case TextVariant.Caption:
      case TextVariant.Status:
        return $r('app.color.text_secondary');
      default:
        return $r('app.color.text');
    }
  }

  private pickLetterSpacing(): number {
    switch (this.variant) {
      case TextVariant.Title:
        return 0.6;
      case TextVariant.Heading:
        return 0.4;
      case TextVariant.Subtitle:
        return 0.3;
      case TextVariant.Body:
        return 0.2;
      case TextVariant.Label:
      case TextVariant.Status:
        return 0.2;
      case TextVariant.Caption:
        return 0.1;
      case TextVariant.NavLabel:
        return 0.2;
      case TextVariant.Action:
        return 0.3;
      case TextVariant.Metric:
        return -0.5;
      default:
        return 0;
    }
  }

  private pickLineHeight(): string {
    switch (this.variant) {
      case TextVariant.Title:
        return '34fp';
      case TextVariant.Heading:
        return '26fp';
      case TextVariant.Subtitle:
        return '22fp';
      case TextVariant.Body:
        return '24fp';
      case TextVariant.Label:
        return '20fp';
      case TextVariant.Caption:
        return '18fp';
      case TextVariant.NavLabel:
        return '14fp';
      default:
        return '24fp';
    }
  }
}
