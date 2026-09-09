## ADDED Requirements

### Requirement: Lists animate changes using stable identities
设备、订单及进行中任务 SHALL 以稳定业务身份呈现增删变化，保留项持续可见并平滑让位；空态与内容之间具有连续过渡。

#### Scenario: Add and remove an ongoing task
- **WHEN** 已有洗衣任务时热水任务加入或结束
- **THEN** 仅热水项进入或退出，洗衣项保持身份且平滑调整位置，不随整排重播淡入

#### Scenario: Add or rename a device
- **WHEN** 新增或改名成功
- **THEN** 弹窗关闭，列表以设备 ID 找到对应项并短暂突出；失败时保留输入和错误

### Requirement: Local selections and messages transition in place
分类、洗衣选项、错误提示及状态内容 SHALL 局部更新，关联布局平滑调整，首次出现及最终消失同样拥有过渡。

#### Scenario: Switch category and clear an error
- **WHEN** 用户切换订单分类或错误信息从有变无
- **THEN** 分类标记与关联内容衔接，错误区域退出后周围内容平滑补位，其他区域不重播入场

### Requirement: Successful login preserves page context
应用 SHALL 在已确认登录成功后于当前账号页从表单过渡到账号信息，保留既有默认系统规则，并合理处理键盘与焦点。

#### Scenario: Login succeeds or fails
- **WHEN** 账号登录请求返回
- **THEN** 成功原地展示账号信息并移除表单焦点；失败保留可重试输入和真实错误，不导航离开且不播放成功状态

### Requirement: Drinking completion remains available for user review
应用 SHALL 以当前订单 ID 绑定的已确认终态快照原地呈现接水结果，完成后由用户主动选择返回首页；活动订单清理与轮询停止继续遵循业务规则。

#### Scenario: Confirmed completion clears active order
- **WHEN** 当前接水订单被确认为完成且 runtime 清理活动订单
- **THEN** 页面保留该订单结果摘要和返回首页操作，不自动导航，首页进行中按业务终态移除

#### Scenario: Stale or failed response arrives
- **WHEN** 查询失败、订单取消或旧订单响应在新流程开始后到达
- **THEN** 失败和取消按真实状态展示，旧响应不覆盖新结果，不把空订单或历史记录误认为本次成功

#### Scenario: Repeat completion and leave result
- **WHEN** 同一订单重复报告完成，随后用户选择返回首页
- **THEN** 完成过渡最多触发一次，用户回到首页并恢复底栏；仅清理本次展示状态，历史记录继续可查
