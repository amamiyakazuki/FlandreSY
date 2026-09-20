## Why

> 2026-09-19：以下为原变更背景；热水恢复和控制规则已按用户要求更新为手动控制与 40 分钟恢复，详见同目录规格及设计首段。原订单核对/轮询提案不再作为当前验收依据。

设备不在蓝牙范围内时，当前热水启动流程会在真正发送设备指令前就持久化进行中 session；启动失败后仍进入订单轮询，重启应用又会恢复该 session，最终形成无法自行退出的“订单查询失败”状态。与此同时，工作区中针对该问题的未完成修改无法通过 Dart 编译，普通 APK 构建因此在 Flutter kernel snapshot 阶段失败，发布脚本还存在版本清单路径与当前版本不一致的问题。

## What Changes

- 将热水启动 session 明确划分为准备、启动中、结果不确定和已确认运行四个阶段，并为持久化数据提供版本兼容。
- 启动指令发送前发生的扫描、连接、握手、订单创建等确定性失败清理本地 session、停止轮询并恢复可重试状态。
- 启动指令已经发送但响应丢失时保留不确定 session，重启或回到前台后只使用只读查询进行核对。
- 为旧版 session、缺少关水凭据或无法自动确认的状态提供带二次确认的本地解除入口；该操作只清除 App 本地记录，不宣称已关闭设备。
- 保证会话绑定原账号、系统、设备和订单，过滤过期异步回调，并在成功关水或明确本地解除后清理相关安全凭据。
- 增加覆盖距离外启动、启动响应超时、旧版 session 恢复、轮询失败、显式停止和状态持久化的回归测试。
- 修复当前未完成改动造成的 Dart 编译错误，并使普通 release APK 构建通过静态分析与编译验证。
- 修正 Android 发布脚本使用的版本清单来源和前置校验，使其与 `pubspec.yaml`、`assets/public/version.json` 及签名配置的实际约定一致。

## Capabilities

### New Capabilities

- `android-release-build`: 定义 Android release APK 构建前的版本一致性、签名配置和编译验证规则。

### Modified Capabilities

- `hotwater-status-reconciliation`: 增加启动阶段语义、确定性失败回滚、旧 session 兼容清理和本地解除规则。

## Impact

- Flutter runtime 的热水状态模型、启动/恢复/轮询 action、住理热水 adapter 及安全凭据持久化。
- 热水详情页和首页热水状态入口，新增异常 session 的本地解除交互。
- 热水 session 的 JSON 版本格式和相关 SharedPreferences/secure storage key；旧格式需要可读并安全降级。
- 热水 runtime、adapter contract、持久化 repository 和 widget/单元测试。
- `tools/release/build_android_release.sh`、版本清单路径、Android release 构建校验；不新增第三方依赖。
