import router from '@ohos.router';

/** 兼容旧入口，跳转主壳 */
@Entry
@Component
struct Index {
  aboutToAppear(): void {
    router.replaceUrl({ url: 'pages/Main' });
  }

  build() {
    Column() {
      Text('加载中…')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
