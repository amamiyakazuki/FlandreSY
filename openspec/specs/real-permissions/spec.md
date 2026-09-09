# real-permissions Specification

## Purpose
定义相机、蓝牙和通知权限的真实查询、授权请求、永久拒绝处理及前台刷新。将操作系统授权状态与本地引导确认分离，使用户拒绝授权、进入系统设置修改权限以及返回应用后的界面状态保持一致。
## Requirements
### Requirement: Application checks real permission state
The application SHALL expose real authorization state for camera, Bluetooth, and notifications instead of treating dismissal of an in-app prompt as authorization.

#### Scenario: Permission state is granted
- **WHEN** the application checks a capability already granted by the operating system
- **THEN** it reports that capability as granted and does not request it again

#### Scenario: Permission state is denied
- **WHEN** a capability is denied and the user starts the relevant permission flow
- **THEN** the application requests authorization and reflects the resulting state

### Requirement: Application handles permanent denial
The application SHALL provide a route to system settings when the operating system reports that a required capability cannot be requested again.

#### Scenario: User permanently denies permission
- **WHEN** the permission API reports a permanently denied capability
- **THEN** the UI offers an action that opens this app's system settings

### Requirement: Permission state refreshes on lifecycle return
The application SHALL re-check relevant permissions when returning to the foreground.

#### Scenario: User changes permission in system settings
- **WHEN** the app resumes after system settings changed a capability
- **THEN** the in-app permission state reflects the new authorization without requiring a restart
