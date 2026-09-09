## ADDED Requirements

### Requirement: Immediate and cancellable activation feedback
应用 SHALL 对每个有效可交互控件的激活提供即时视觉反馈；动作不等待动画完成，单次激活只能触发一次业务回调。

#### Scenario: Activate and cancel a control
- **WHEN** 用户按下可用按钮并拖出取消
- **THEN** 按钮恢复静止外观且不执行业务动作

#### Scenario: Keyboard activation and disabled controls
- **WHEN** 用户以键盘激活聚焦控件，或尝试激活禁用控件
- **THEN** 可用控件提供可见反馈并仅执行一次，禁用控件不执行业务动作且不显示成功反馈

### Requirement: Asynchronous feedback reflects verified outcomes
应用 SHALL 在提交后显示处理中并阻止同一操作重复请求，依据真实结果显示成功或失败；动画 MUST NOT 推导或提前宣告业务成功。

#### Scenario: Slow operation fails
- **WHEN** 用户提交操作后请求延迟并失败
- **THEN** 控件即时回应并保持处理中，随后恢复可操作状态并就近显示错误，按钮外部尺寸不因标签替换跳动

### Requirement: Motion respects accessibility and update intent
应用 SHALL 响应系统减少动效设置，保留状态反馈和可操作性；无变化轮询、倒计时及重复状态通知 MUST NOT 重播入场或成功动效。

#### Scenario: Reduced motion is enabled
- **WHEN** 用户启用系统减少动效后点击、导航或打开弹窗
- **THEN** 不播放空间位移、缩放回弹或固定开场等待，状态即时或短淡变更新且焦点和操作正常

#### Scenario: Background update repeats current state
- **WHEN** 轮询结果与当前状态一致或倒计时经过一秒
- **THEN** 仅必要数据更新，不重播整页或条目入场，不新增结果强调
