# Android 调试包共存

- 用户需要无数据线时通过APK安装测试，debug与release共存。
- release保持com.flandresy/芙兰水衣；debug使用com.flandresy.debug/芙兰水衣 Debug，版本后缀-debug，Android Debug签名。
- namespace与MainActivity保持com.flandresy，provider使用applicationId动态展开；不用改Kotlin包名。
- 构建：flutter build apk --debug --target-platform android-arm64。APK位于build/app/outputs/flutter-apk/app-debug.apk。
- 两个版本的本地数据与权限独立，不自动迁移登录或订单。默认仍真实后端；同一服务端订单避免两个版本同时操作。
- 2026-09-19版本2.1.2-debug（4）构建及v2签名验证成功；没有USB安装/手机现场证据，支付外部签名约束需实测。
# 2026-09-20 幂等修复重建

- `build/app/outputs/flutter-apk/app-debug.apk`已替换为包含热水幂等修复的新arm64 debug包，包名仍为com.flandresy.debug，可覆盖旧Debug、与release共存。
- SHA-256：2bc8b729e80ea5ab99738d1c2e7de4394d9f2693b942be0984dd279c170fed48；apksigner验证通过。之前SHA对应旧构建，不含本次修复。
- 全量129项、热水40项通过，分析无诊断；不代表实体水流已验收。
