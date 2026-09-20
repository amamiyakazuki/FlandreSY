# CI A 决策与验证

- 最终远端验收：修复提交c2de043已推送main，运行35479433772在7分钟内全部success，SDK准备、分析/测试、Debug ARM64构建与artifact上传均通过。下方“远端尚未执行”是历史状态。Node20/setup-java v4告警仍待后续维护，本轮不影响成功；未改iOS或发布。

- 首次push 1bd382d远端分析/测试通过，但SDK步骤找不到PATH中的sdkmanager（运行35479232027）。用户授权修复再推送：显式用ANDROID_HOME/ANDROID_SDK_ROOT下cmdline-tools/latest/bin/sdkmanager，不再假设预装等于在PATH；远端结果以随后运行记录为准。

- 用户选择A：静态分析、全量Flutter测试、Android Debug ARM64构建、保留APK；不增加Release检查或发布，不测试真实支付/BLE。热水用户现场通过已收口，支付按用户要求跳过。
- 工作流`.github/workflows/flutter-android-ci.yml`：分支push/所有PR/手动触发，ubuntu-24.04、Flutter3.44.4、Temurin17；固定Action SHA。contents只读、checkout不保留凭据、按事件与ref取消旧运行、45分钟上限，产物7天。
- SDK36/build-tools36.0.0/NDK28.2.13676358与当前Flutter/AGP相配；Gradle仅CI环境覆盖3GiB堆与2 workers，不改项目本地配置。锁文件强制解析，不自动更新依赖。
- 现有iOS工作流保持原样（Flutter3.44.3），本轮不声称跨平台统一SDK；未设置分支保护/通知渠道/发布签名。
- 本地pub/analyze/129测试/debug构建/actionlint已过；Ubuntu远端尚未执行。README提供下载入口与临时签名警示；不得为装CI包贸然卸载有活动订单的旧应用。
- 推送授权尚未取得；目前工作树包含此前大量业务修复与测试，不得只推送工作流就声称这些未提交修复已被远端验证。
