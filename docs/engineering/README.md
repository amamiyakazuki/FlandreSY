# 工程计划与验收

本目录跟踪可公开的范围、决定与验收证据。详细本地工作记录保留在 P_PLAN，不提交日志、账号数据、支付串或凭据。

[P0 / P1 / P2 优先级总览](priority-overview.md)：先看待处理问题、条件风险和已修复待验项，再决定下一模块。

## 当前模块

| 模块 | 范围 | 状态 |
|---|---|---|
| [C1 去模拟与数据保全](c1-remove-simulation-plan.md) | 移除产品模拟模式，保护升级前账号与活动记录 | 已合入 main 86697a9；本地、CI 通过，真机待验；PR #4 已归档隐藏 |
| [C3a 接口结果校验](c3a-response-contract-plan.md) | U净 / 798 异常响应不伪报成功，保留未确认记录（RA-13） | 已合入 main 606a11c；本地 288 通过 / 1 跳过，两平台 CI 通过；[验收](c3a-response-contract-acceptance.md) |
| [C2 本地设备一致性](c2-device-consistency-plan.md) | 刷新与编辑不互相覆盖、导入校验、真实刷新与保存反馈（RA-02/03/14） | 已按全部 A 实现；本地 338 通过 / 1 跳过，交付核验见[验收](c2-device-consistency-acceptance.md) |

[当前验收记录](c2-device-consistency-acceptance.md)。洗衣状态、历史归属、平台适配等其他模块尚未启动。

C1 合入后的 main CI：[Android](https://github.com/amamiyakazuki/FlandreSY/actions/runs/38860214079)、[iOS](https://github.com/amamiyakazuki/FlandreSY/actions/runs/38860213953) 均通过，对应 86697a9670520addaf84de2cb924789dde99c49f。旧 C1 验收文件的 PR 交付段落保留当时记录，当前状态以此处为准；归档 PR 不再作为唯一公开证据入口。

C3a main CI：[Android](https://github.com/amamiyakazuki/FlandreSY/actions/runs/38864439197)、[iOS](https://github.com/amamiyakazuki/FlandreSY/actions/runs/38864439307) 均通过，对应 606a11c6922eca1e4efdf07b1769c359525c57d2。C2 新增 50 项专项测试，全量 338 通过 / 1 跳过。

## 已确认的交付方式

用户于 2026-10-16 调整交付方式：保留模块分支、Git 提交、测试、推送 GitHub 和 CI 检查，不再要求创建 PR。合并和正式版本发布仍按用户授权处理。一个模块完成后更新状态，再决定下一模块。

C1 已按用户后续授权直接合入 main、推送 GitHub 并归档隐藏 PR #4，未发布版本。C3a 也已获单独授权：A 方案实现，测试后合入 main、推送并确认 CI，随后停止，不创建 PR、不发布。C2 随后也已获全部 A 实施、合入 main 和推送授权，沿用无 PR / 无发布 / CI 核验后停止；其他模块未获实施授权。

## 记录要求

- 计划写目标、边界、未决事项与验收标准；不以任务勾选代替证据。
- 验收写确切提交、命令/场景、结果与未验证项。
- “代码检查”“自动测试”“构建”“真机”“服务端确认”分开记录。
- 不把旧提交的测试结果当成本模块的新证据。
