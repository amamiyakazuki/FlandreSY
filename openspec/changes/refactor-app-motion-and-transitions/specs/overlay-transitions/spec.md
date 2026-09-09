## ADDED Requirements

### Requirement: Overlays retain their lifecycle through exit
应用自有弹窗及菜单 SHALL 具有完整进入和退出过渡，退出期间保留遮罩拦截，关闭后恢复合理焦点；系统弹窗继续使用平台行为。

#### Scenario: Close an overlay rapidly
- **WHEN** 用户打开设备菜单后快速关闭并再次点击其后方控件
- **THEN** 退出未完成期间点击不穿透，关闭仅处理最上层，焦点返回仍存在的触发入口

### Requirement: Overlay steps share a stable background
应用 SHALL 在添加设备到预设选择等内部步骤间保留单一遮罩，以内容过渡及尺寸变化表达下一步；返回先退出当前步骤。

#### Scenario: Choose preset then return
- **WHEN** 用户从添加设备进入预设选择再返回
- **THEN** 回到添加设备，遮罩不闪灭，不同时出现两个可交互弹窗

### Requirement: Overlay content remains reachable
弹层 SHALL 适配触发位置、视口、键盘和字体尺寸，保证内容可滚动且关键操作不被遮挡。

#### Scenario: Edit a name with large text and keyboard
- **WHEN** 用户在窄屏和 200% 字体下打开编辑名称并显示键盘
- **THEN** 输入和保存/取消可达，文字无非预期重叠，尺寸过渡不会把操作移出可访问区域
