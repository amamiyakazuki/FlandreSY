# C6a 验收：更新入口与发布工具

2026-10-17。用户选择“1A2A3A，开始”。仅实施 C6a，沿用模块分支、测试后合入 main 并推送、确认 CI 后停止，无 PR、无发布。C6b 正式候选与覆盖安装待单独确认。

代码提交 `16af1858dac297358d4024cf8142226b4f0db76b`，模块分支 `codex/c6-update-release`。本记录随后提交，仅补工程文档。

## 实际行为

- Android 正式包使用真实版本、构建号和包名判断更新；旧清单继续可读，但缺少构建信息时只提供发布说明，不能暗示可直接覆盖。显示版本变大而内部码不够时也不直接下载；同版本更高构建可更新。
- iOS 明确暂无更新渠道，不打开 APK、不声称已最新；Debug 是独立安装，提供正式版信息，不承诺覆盖。
- 本机版本读取失败显示未知，不再回退 2.1.1。坏字段/类型/版本/schema/链接返回失败；只允许本仓库 HTTPS Release 的正确版本通用 APK 或发布说明。
- 下载导航 false/异常均有重试反馈，重复点击合并；离页后的迟到结果忽略。成功只表示链接打开，长说明和大字号可滚动。
- 发布默认通用 ARM64+x64 APK，AAB 显式选用并单独核验。候选版本与在线稳定清单分离，旧客户端字段/路径保留；当前 pubspec、两份 2.1.4 清单和依赖锁未修改。
- Java Properties 标准解析统一签名路径为相对 android/，支持绝对/空格/转义/续行；正式 release 不回退 Debug。独立 Debug 不需要正式密钥。
- 正式预检要求真实历史 APK 和可信哈希，至少包含 2.1.4 三种包，检查实际版本码/身份/证书/ABI；候选必须超过全部所选旧包。不能填一个 4007 就宣称兼容全历史。
- 工具核验新产物实际元数据与历史签名；仅报告本次新输出，附源码提交、工具信息、哈希/大小。清单准备工具检查对应 Release 已公开且非预发布、资产大小与重新下载的字节哈希一致后，只写候选 JSON，不改在线清单、不上传。

## 本地证据

| 检查 | 结果 |
|---|---|
| Flutter 专项（新增 69，原有版本测试 3） | 平台、未知元信息、版本/构建比较、旧清单、错误类型/JSON/schema/URL、网络失败/超时、浏览器失败/重试/并发/销毁、更多页完整请求及重试、大字号全部通过 |
| Flutter 全量 | `flutter test --no-pub`：**522 通过、1 原有可选截图跳过** |
| 发布工具 | `python3 -m unittest discover -s tools/release/tests -v`：**21 通过**；含 Java 标准属性/路径、实际文件哈希、历史基线、错误证书/包名/ABI/版本、缺工具、陈旧输出、完整模拟构建、按需 AAB、公开资产与清单门禁 |
| 静态检查 | `flutter analyze --no-pub` 无诊断；脚本 Bash 语法、`git diff --check` 通过 |
| 不发布验证 | pubspec、pubspec.lock、assets/public/version.json、public/version.json 对基线无修改；无正式签名构建/上传/版本发布 |

首次新增测试发现 macOS 临时目录规范化差异、模拟构建未恢复测试工作目录、集成测试按钮文字不匹配，均修复测试后重跑通过；没有跳过失败用例。测试中的 APK/密钥内容均为临时假资料，工具返回值由测试注入，不执行真实设备或签名操作。

## GitHub CI 核验

要求**本记录所在 main 提交**的 [Android CI](https://github.com/amamiyakazuki/FlandreSY/actions/workflows/flutter-android-ci.yml?query=branch%3Amain) 和 [iOS CI](https://github.com/amamiyakazuki/FlandreSY/actions/workflows/ios-build.yml?query=branch%3Amain) 成功。Android 新增离线发布工具测试，并在正常 Debug 构建后验证“无 key.properties 的 release 签名门禁必须失败”；不使用正式密钥。最终提交和精确运行链接登记在交付回复与本地 P_PLAN。

## 未验与保留边界

未读取真实签名密码、未生成正式候选、未重新盘点全历史 APK、未安装或卸载应用、未操作账号/支付/BLE、未发布。真实签名候选、覆盖旧通用/ARM64/x64 包及 C1 数据保全仍待 C6b。RA-09 的入口/工具已修复，但不能标为历史安装兼容已验收；已发布 2.1.4 的旧客户端行为不会因本次源代码合入自动改变。

工具用法见 [发布工具说明](../../tools/release/README.md)。C5b、D1/E1、商店上架与工具链升级均未扩展。
