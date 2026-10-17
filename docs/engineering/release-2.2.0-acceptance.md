# 2.2.0 发布记录

2026-10-17。用户报告“测试通过了，直接发布 2.2.0”，授权合入 main、推送与正式发布；取代此前本地暂存限制。不创建 PR。

## 公开版本与产物

- [正式 Release](https://github.com/amamiyakazuki/FlandreSY/releases/tag/v2.2.0)，公开时间 `2026-10-17T05:34:13Z`（东京时间 14:34:13），非草稿、非预发布，GitHub latest 指向 v2.2.0。
- 版本 `2.2.0+5000`，通用 APK 的 Flutter 运行架构为 ARM64 / x86_64；原正式签名、包名 `com.flandresy`。大小 71,454,334 字节。
- [APK](https://github.com/amamiyakazuki/FlandreSY/releases/download/v2.2.0/app-release.apk)；[校验和](https://github.com/amamiyakazuki/FlandreSY/releases/download/v2.2.0/SHA256SUMS.txt)。SHA-256：`25666572248bb623864b87efdc0d47b29f500205e2a276f41b3edb20c80a4311`。
- 使用此前构建并由用户反馈测试通过的同一个文件，没有重构建。带注释标签 `v2.2.0` 指向 APK 源码提交 `05f7f010117afd07973c0c0c763bc6e02e817b55`；后续提交仅涉及文档、测试夹具与公开更新清单。
- 未上传新专用 APK、AAB 或 iOS 分发包；旧 Release/资产保留。

## 检查与交付

- 产物检查及本地构建结果见[候选记录](c6b-local-candidate-2.2.0.md)：624 Flutter 测试通过/1 原有跳过、分析通过、24 项发布工具离线测试通过，旧包摘要/签名/版本码和候选身份通过。
- 发布前 main `5b336e9be857d8379e6904692ac9ab545e03d663`：[Android CI](https://github.com/amamiyakazuki/FlandreSY/actions/runs/39006287782)、[iOS CI](https://github.com/amamiyakazuki/FlandreSY/actions/runs/39006287772) 均 completed/success。模块分支已推送，main 快进合入，无 PR。
- 发布工具测试改为独立的 2.1.4 历史夹具，避免当前稳定清单更新后测试错误地把“历史版本”也更新为 2.2.0；不修改生产判断或 APK。
- Release 公开后，`prepare_stable_manifest.py` 重新下载公开 APK，核对实际 SHA-256 与本地候选一致后才生成新清单。两份稳定清单同步为 2.2.0 / 5000，保留旧客户端字段与路径；iOS 明确 unavailable。
- README 和 Release 仅展示功能迭代、修复、使用说明及下载入口；工程验证保留在本目录。用户测试反馈按原话记录，未推断其完成所有历史包安装路径。
- 新稳定清单下本地更新功能专项 72 项通过、发布工具 24 项通过，文档引用及差异检查通过。
- 最终在线清单提交推送后继续检查同提交 Android/iOS CI，以及两条远端清单路径和下载指向；结果记在本次交付回复与本地工作记录，不复用发布前 CI 结果。

## 证据边界

用户已确认测试通过并批准此次发布；未提供逐条设备/系统/旧包记录，因此 C6b 原 12 路径和完整数据组不自动改为全部通过。公开 APK 的下载摘要核对已完成，手机端各旧客户端的实际在线更新操作没有由助手执行。未新增真实账号、付款、设备控制或清理用户数据的操作。
