## ADDED Requirements

### Requirement: Navigation expresses hierarchy and supports interruption
应用 SHALL 区分主 Tab 并列切换与详情进入/返回，返回沿进入关系恢复；快速输入以最新有效目的地为准，旧页面不可继续接受交互。

#### Scenario: Rapid tab selection
- **WHEN** 用户在一次转场完成前连续选择订单、设备和我的
- **THEN** 最终显示我的且底栏一致，不排队播放旧目标，不重复创建同一目标

#### Scenario: Return from account details
- **WHEN** 用户从账号中心进入账号详情后使用页内返回、系统返回或受支持的返回手势
- **THEN** 均回到账号中心并执行对应反向过渡，不跳过父层，不修改默认系统

### Requirement: Bottom navigation follows task focus
应用 SHALL 在主页面、账号中心、更多选项、账号详情、热水详情及空设备页保留底栏，在扫码、洗衣下单/支付和接水订单/结果页隐藏底栏；显隐与页面及内容占位同步。

#### Scenario: Enter and leave a focused flow
- **WHEN** 用户进入洗衣或接水流程后返回入口
- **THEN** 底栏随进入隐藏、随返回恢复，安全区不重复计算，页面不在过渡结束后突然重排

### Requirement: Browsing state survives navigation without duplicate work
应用 SHALL 保留主页面滚动位置、订单分类及有效选择；保活页面 MUST NOT 产生重复计时器或页面专属后台轮询，业务要求的退出清理仍然执行。

#### Scenario: Restore an orders category
- **WHEN** 用户选择洗衣分类、滚动、离开后返回订单页
- **THEN** 恢复分类及合理滚动位置，UI 时钟及页面轮询至多各有一个实例

### Requirement: Scanner and payment handoffs preserve outcome integrity
应用 SHALL 为扫码取消/识别及外部支付返回提供连续交接，平台拥有系统界面动画，应用不得以恢复前台作为支付成功依据。

#### Scenario: Scanner cancellation or repeated recognition
- **WHEN** 用户取消扫码或相机连续识别同一码
- **THEN** 取消恢复原入口，识别只触发一次目标导航和对应业务操作

#### Scenario: Return from payment app
- **WHEN** 用户从支付宝返回应用
- **THEN** 恢复原订单流程并依据支付协议或核验结果呈现处理中、成功、失败或取消，不自动显示成功
