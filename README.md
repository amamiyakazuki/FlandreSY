<p align="center">
  <img src="ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png" alt="FlandreSY App Icon" width="120">
</p>

# 芙兰水衣 FlandreSY 2.1

`芙兰水衣`（FlandreSY）是一款面向校园与公寓生活场景的 Flutter 应用，统一管理洗衣、饮水、热水与慧生活 798 服务。2.1 版本重点重构了页面动效、账号入口、订单状态恢复和在线更新链路。

## 项目截图

<p align="center">
  <img src="docx/s1.jpg" alt="FlandreSY Screenshot 1" width="30%">
  <img src="docx/s2.jpg" alt="FlandreSY Screenshot 2" width="30%">
  <img src="docx/s3.jpg" alt="FlandreSY Screenshot 3" width="30%">
</p>


## 项目状态

- 应用显示名：`芙兰水衣`
- 英文品牌名：`FlandreSY`
- Android 包名：`com.flandresy`
- iOS Bundle ID：`com.flandresy`
- 正式版营销版本：`2.1.1`
- Flutter 构建版本：见 `pubspec.yaml`
- 默认运行模式：真实后端

## 2.1 版本重点

- 统一页面、弹窗、列表和操作反馈的动效节奏
- 增加统一账号中心，并明确住理生活、慧生活 798 与 U净的状态
- 持久化热水会话和饮水订单，恢复应用后继续核对状态
- 在“更多选项”中在线检查版本并直接打开 APK 下载地址

## 主要能力

- 洗衣流程：设备识别、下单、支付、订单状态与历史
- 饮水流程：扫码、创建订单、刷新状态、历史保留
- 热水流程：账号、设备、会话恢复、状态轮询、历史与真实 BLE 接入
- 798 流程：账号、设备选择、洗浴控制与状态轮询
- 更多选项：在线更新、诊断日志、权限检查与设备列表导入导出

## 仓库结构

- `lib/`：Flutter 2.0 主代码
- `android/`：Android 工程与发布签名配置
- `ios/`：iOS 工程、Podfile 与发布配置
- `assets/legacy/`：从旧版整理出来并继续复用的图片/字体资源
- `assets/public/`：应用内置及远程读取的版本清单
- `tools/release/`：发布辅助脚本
- `P_PLAN/`：规划、审查记录、发布清单与设计约束
- `docx/`：README 展示用截图资源

## 本地开发

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

默认走真实后端。若需要无账号、无设备的纯演示模式：

```bash
flutter run --dart-define=SIMULATE_BACKEND=true
```

## 版本与更新链路

- 内置版本清单：`assets/public/version.json`
- 远端版本清单：`https://raw.githubusercontent.com/amamiyakazuki/FlandreSY/main/assets/public/version.json`
- GitHub Releases 下载页：
  - `https://github.com/amamiyakazuki/FlandreSY/releases/latest`

发版时需同步更新 `pubspec.yaml` 与 `assets/public/version.json`，并确保清单中的下载地址指向已经上传的 GitHub Release asset。

## Android 发布

1. 复制 `android/key.properties.example` 为 `android/key.properties`
2. 填入真实 keystore 路径、alias 与密码
3. 运行统一校验与构建脚本：

```bash
bash tools/release/build_android_release.sh
```

如果只想先检查签名配置是否齐全：

```bash
bash tools/release/build_android_release.sh --validate-only
```

说明：
- 仓库已经接好 release signing 自动读取逻辑
- `android/key.properties` 缺失时，Gradle 会回退到 debug signing，只能用于本地验证，不可正式分发
- 为保证 beta 用户可原地升级到正式版，Android `applicationId` 当前保持为 `com.flandresy`
- 对于 GitHub Releases 分发，当前更推荐把 `app-release.apk` 作为主安装包

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

## 开源许可

This project is licensed under the GNU Affero General Public License v3.0. See `LICENSE` for details.
