# C2 验收：设备列表一致性、导入与刷新

日期：2026-10-16。用户已批准全部 A 方案，实现后合入 main、推送 GitHub；沿用不创建 PR、不发布、核对 CI 后停止。

代码提交：`11924e6`（`fix(devices): serialize saved edits and validate confirmed imports`）。本记录随后的文档提交不改生产代码。模块分支：`codex/c2-device-consistency`。

## 实现结果

- 所有本地设备写入共用运行时串行提交入口，执行时读取最新列表，保存完成后才发布；热水结束只改同一保存入口，不改启停协议或会话规则。保存失败不冒充关水失败。
- 网络不占保存队列，刷新只回填仍对应原记录的状态。删除、导入复用 ID、旧菜单、账号切换和销毁均有保护。刷新在途标记、编辑通知、保存状态相互独立。
- 导入整批严格校验；确认弹窗展示新旧数量，包含隐藏旧记录。列表变化须重新确认，保存失败可原内容重试。空数组不能清空，导入不自动查询。
- 新导入只支持 washer / drinkingWater；旧库仍用原 codec，保留隐藏类型及歧义记录。歧义 ID 禁止定位写回；ID 分配兼顾尾号、排序值及现有集合。
- 成功、失败、跳过分开汇总。缓存状态标为历史；导入、重启、查询失败或账号变化后不计入首页当前可用数。成功状态标明查询时点；可信标记不落盘、不信任导入值。
- SharedPreferences 返回 false 或异常时重载缓存再报告失败。成功通知计时器只清除自己的通知，不能清掉后来的共享保存错误。

## 验收证据

先在旧代码复现两项失败：刷新覆盖新名称、`[{}]` 导入被接受；修复后均通过。

| 范围 | 自动验证 |
|---|---|
| C2-01 / 02 / 03 | 延迟刷新期间新增、改名、删除；持久化/重建一致；同 ID 重建与旧菜单隔离；通知消失不释放刷新锁 |
| C2-04 / 05 / 06 | 21 类非法导入、合法导出往返、替换确认过期、取消、保存失败重试、不发网络；尾号 900 后分配 901，重启后 902 |
| C2-07 / 08 | 部分成功、全失败、零查询、保存失败、恢复成功；历史可用值保留但不计数；导入清除旧刷新时间 |
| C2-09 | 编辑与热水结束共享队列；本地保存失败时关水确认仍成立；正式 SharedPreferences 平台接口注入 false / 异常及成功重试 |
| C2-10 / 11 | 切号/登出/销毁/鉴权错误；写盘期间切号；C1 重登门禁；隐藏、空 ID、重复 ID 的旧记录保持；C3a 全量回归 |
| C2-12 | 改名错误保留输入、重复保存防护；导入原内容重试及取消；320 宽、1.8 倍文字下错误和部分失败提示无布局异常 |
| C2-13 本地 | `flutter analyze --no-pub`：无诊断；`flutter test --no-pub --reporter expanded`：338 通过 / 1 跳过；`git diff --check`：通过 |

专项位于 `test/c2_devices_test.dart`、`test/c2_devices_ui_test.dart`、`test/c2_storage_and_hotwater_test.dart`，共新增 50 项。已有弹窗动效测试随异步保存接口适配。测试依赖显式声明已锁定的 `shared_preferences_platform_interface 2.4.2`，未升级运行期依赖。

远端交付要求：以**本验收记录所在 main 提交**的 GitHub checks 为准，Android 分析/测试/debug 构建和 iOS 构建都成功后才结束本模块。入口：[Android main](https://github.com/amamiyakazuki/FlandreSY/actions/workflows/flutter-android-ci.yml?query=branch%3Amain)、[iOS main](https://github.com/amamiyakazuki/FlandreSY/actions/workflows/ios-build.yml?query=branch%3Amain)。确切运行链接在交付回复与本地 P_PLAN 交付记录中登记，不把上个模块的 CI 当作本次证据。

## 验证限制

- 1 项跳过是既有可选截图测试；本次 UI 验证为 widget 交互/布局断言，不是完整视觉验收。
- 存储失败使用平台通道故障注入，未在实体设备模拟磁盘满、系统杀进程或覆盖升级。
- 未操作真实账号、支付、蓝牙或热水设备；真实服务兼容性和 C1 旧数据升级仍待真机验证。
- 未处理 C3b、C4、C5、D1 等其他模块；未改 798 服务端收藏列表竞争、订单协议或发布配置。
