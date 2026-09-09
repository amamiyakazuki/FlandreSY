# home-status Specification

## Purpose
保证首页只呈现有用的操作状态与错误，移除没有操作价值的泛化引导。区分真实服务错误、可验证状态与无效说明，确保无消息时界面保持简洁，发生操作失败时仍保留完整且可读的错误信息。
## Requirements
### Requirement: Home status cards show actionable state only
Home status cards SHALL omit generic instructional or warning copy that does not correspond to an available action, while retaining actionable errors and verified service status.

#### Scenario: Hotwater card has no message
- **WHEN** the hotwater card has no actionable error or verified status message
- **THEN** it does not display the generic text about viewing current status and executing operations

#### Scenario: Hotwater card has an actionable error
- **WHEN** a service operation returns an actionable error
- **THEN** the card displays the error without truncating its meaning
