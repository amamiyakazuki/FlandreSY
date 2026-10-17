# 开发与维护说明

功能介绍和下载入口见 [README](../README.md)。本文保留开发、CI 与发布流程；公开更新说明只描述功能迭代和修复。

## 仓库结构

- `lib/`：Flutter 应用代码
- `android/`：Android 工程与发布签名配置
- `ios/`：iOS 工程、Podfile 与发布配置
- `assets/legacy/`：从旧版整理出来并继续复用的图片/字体资源
- `assets/public/`：应用内置及远程读取的版本清单
- `tools/release/`：发布辅助脚本
- `docs/engineering/`：可公开的计划与验收记录
- `P_PLAN/`：本地规划与过程记录（不随仓库分发）
- `docx/`：README 展示用截图资源

## 本地开发

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

应用仅使用真实后端，模拟模式及其运行参数已移除。离线测试使用 `test/support` 中显式注入的替身，不连接真实账号、支付或设备。

升级时先保全旧数据，各服务首次使用需重新登录。来源不明的活动记录核对前不会自动删除或控制设备；在“更多选项 → 旧数据保全”查看进度并重试。详见 [C1 计划与验收](engineering/README.md)。

## 持续集成（CI）

`.github/workflows/flutter-android-ci.yml` 在分支 push、PR 和手动触发时顺序执行：

1. 使用 Flutter 3.44.4、JDK 17 和已提交的 `pubspec.lock` 安装依赖。
2. `flutter analyze --no-pub` 与全量 `flutter test --no-pub --reporter expanded`。
3. 构建 Android ARM64 Debug APK；前面的检查失败则不构建、不上传。
4. 将 APK 保存为 `flandresy-debug-arm64-<run_id>-<run_attempt>`，保留 7 天。

推送后在 GitHub 仓库 **Actions → Flutter Android CI → 对应运行 → Artifacts** 下载并解压 APK。手动运行入口需工作流先存在于默认分支。本配置不发布 GitHub Release、不读取正式签名密钥、不执行真实支付或 BLE 操作；iOS 工作流独立执行无签名构建检查。

APK 包名为 `com.flandresy.debug`，可与正式版共存，但托管 runner 的临时 Debug 签名不保证与本机或其它次构建相同；不能保证覆盖现有 Debug 安装。不要为安装测试包贸然卸载仍有活动订单的旧版本，卸载会丢失其本地数据。默认真实后端，安装后控制设备或付款仍会产生真实效果。

本工作流提供检查结果，但尚未配置分支保护的强制合并门禁。失败先看对应步骤日志；无需为重试 CI 再次操作真实设备。Action 版本锁定到 commit SHA；升级时同时核对 Flutter、Android SDK/NDK 与 AGP 的兼容要求。

参考：[Flutter Action](https://github.com/subosito/flutter-action)、[AGP 9.0 兼容表](https://developer.android.com/build/releases/agp-9-0-0-release-notes)、[GitHub Artifacts](https://github.com/actions/upload-artifact)。

## 版本与更新链路

- 内置版本清单：`assets/public/version.json`
- 远端版本清单：`https://raw.githubusercontent.com/amamiyakazuki/FlandreSY/main/assets/public/version.json`
- GitHub Releases 下载页：
  - `https://github.com/amamiyakazuki/FlandreSY/releases/latest`

候选构建版本与已公开稳定版清单分开：构建候选时不提前修改在线清单。正式资产公开并核验后，再同步两份稳定清单；旧客户端字段/路径保留。当前稳定清单仍为 2.1.4；2.2.0 尚未发布。

## Android 发布

以后面向用户统一提供 ARM64+x86_64 通用 APK，旧 Release/专用包保留。下一正式包需核验并跨过所选旧包的最高内部版本码，才能支持旧专用包迁移；**当前尚未执行该候选构建或真机覆盖验收**。历史 2.1.4 的安装建议仍以其发布说明为准。

正式发布继续在本地进行。工具先核验历史真实 APK、候选版本与签名配置，使用锁定依赖运行分析/测试，再检查实际产物的包名、版本、签名、架构及校验和。默认只构建通用 APK，AAB 可按需构建；不上传或自动发布。

完整参数与流程见 [发布工具说明](../tools/release/README.md)。缺少正式签名时 release 构建失败，不再回退 Debug 签名；本地普通验证使用独立 Debug 包。保持正式 applicationId `com.flandresy` 和原有签名身份，不能靠卸载解决覆盖升级问题。

## iOS 发布

- 仓库已包含 iOS 工程、Alipay 通道与 Podfile 配置
- 正式发布仍需在 macOS + Xcode + Apple Developer 环境完成签名、Archive 与 TestFlight / App Store 流程
- 若需验证当前 iOS 构建链路，请在 macOS 上执行：

```bash
flutter clean
flutter pub get
cd ios && pod install --repo-update
cd ..
flutter build ios --no-codesign --release
```
