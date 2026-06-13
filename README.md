# 芙兰水衣

<p align="center">
  <img src="app/src/main/res/drawable/ic_launcher_foreground.png" width="112" alt="芙兰水衣 App 图标" />
</p>

芙兰水衣是一款给校园生活场景用的 Android 小工具。它把热水、洗衣、饮水这些零散流程放到一个 App 里，让扫码、下单、支付、查看状态这些步骤更顺手一点。

它不是官方 App，也不替代官方服务。它更像一个轻量的快捷入口：尽量把已经验证过的流程做清楚，把失败原因讲明白，不让人对着一个按钮猜半天。

## 现在能做什么

- 住理热水：登录、绑定设备码、开热水、关热水、查看历史。
- 慧生活798洗浴：短信验证码登录、管理洗浴设备、选择当前设备、开始/结束洗浴。
- U净洗衣：验证码登录、扫码识别洗衣机、选择套餐、洗衣液/除菌液、创建订单、支付宝支付、启动/停止、刷新订单。
- U净饮水：扫码后自动创建接水订单，刷新接水状态，保存历史统计。
- 本地设备列表：保存洗衣机快捷入口，支持海七预置设备、改名、删除、刷新状态。
- 订单页：热水、饮水、洗衣分类展示，当前洗衣订单会显示剩余时间。
- 版本检查：读取远程版本清单，发现新版后引导到下载页面。

## 当前版本

`1.0.2`：支持住理热水、慧生活798洗浴、U净洗衣与饮水流程，洗衣支付支持支付宝。

## 下载与更新

正式安装包会放在 GitHub Releases 里。

1. 打开本仓库的 Releases 页面。
2. 下载最新版本的 APK。
3. 在 Android 手机上安装。

App 内的“更多选项 -> 检查版本”会读取远程版本清单：

- 主源：`https://flandresy.pages.dev/version.json`
- 备用源：`https://raw.githubusercontent.com/amamiyakazuki/FlandreSY/main/public/version.json`

版本清单文件位于仓库的 `public/version.json`。更新版本时，请同步修改 `version`、`release_date`、`changelog` 和 `downloads` 字段。App 会根据清单里的下载链接引导用户获取最新版。

## 自己构建

准备环境：

- Android Studio
- JDK 17
- Android SDK 36

调试构建：

```powershell
.\gradlew.bat --no-daemon "-Dorg.gradle.problems.report=false" assembleDebug
```

Release 构建：

```powershell
.\gradlew.bat --no-daemon "-Dorg.gradle.problems.report=false" assembleRelease
```

如果你要构建可分发的 release 包，需要在本地准备 `keystore.properties` 和签名 keystore。它们只应该留在你自己的电脑里，不要提交到仓库。

`keystore.properties` 示例：

```properties
storeFile=release-key.jks
storePassword=your-store-password
keyAlias=your-key-alias
keyPassword=your-key-password
```

## 数据与隐私

这个项目没有自建后端。App 会直接请求相关服务接口，账号状态、token、设备快捷入口和本地订单历史保存在手机本地。

请注意：

- 不要把抓包文件、token、日志、keystore、`keystore.properties` 提交到仓库。
- 分享日志前请先确认里面没有个人信息。
- 官方接口如果变化，功能可能会失效。

更完整的说明见 [PRIVACY.md](PRIVACY.md) 和 [SECURITY.md](SECURITY.md)。

## 免责声明

本项目与住理生活、U净及相关服务方没有官方关系，也没有得到它们的背书或授权。

项目仅供学习、研究和个人使用。使用本项目造成的账号、订单、支付、设备使用或其它风险，由使用者自行承担。请遵守所在学校、宿舍、服务商和相关平台的规则。

## 开源协议

本项目基于 [MIT License](LICENSE) 开源。
