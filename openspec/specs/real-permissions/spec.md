# real-permissions Specification

## Purpose
定义按需权限、平台差异、拒绝后的恢复及返回前台检查。首次引导已读与操作系统授权分离。C5a 不申请通知，不开放 iOS 住理 BLE 控制；已有会话保留。

## Requirements
### Requirement: Permission checks are read-only and platform-specific
The application SHALL use one shared permission policy for settings, scanning and Zhuli BLE control. Opening the permission screen SHALL only check status.

#### Scenario: Android BLE permission selection
- **WHEN** Android SDK is at most 30
- **THEN** foreground BLE scanning requires locationWhenInUse and separately checks location service availability
- **WHEN** Android SDK is 31 or above
- **THEN** BLE requires bluetoothScan and bluetoothConnect without requesting location
- **WHEN** SDK lookup fails
- **THEN** the application reports a recoverable check error without guessing permissions

#### Scenario: iOS C5a capabilities
- **WHEN** running on iOS
- **THEN** camera uses camera permission; Zhuli control is explicitly unavailable and does not check or request Bluetooth, scan/connect or location
- **AND** login, history and other network services remain available under their existing rules

### Requirement: Authorization is requested only for a relevant user action
The application SHALL request camera when entering scanning and Android BLE when using control, or after an explicit request on the permission screen. First-launch confirmation SHALL only record that the explanation was read.

#### Scenario: Already granted or overlapping requests
- **WHEN** a required permission is already granted
- **THEN** it is not requested again
- **WHEN** permission requests overlap
- **THEN** same-capability requests coalesce and different-capability requests serialize

#### Scenario: Incomplete, unknown or failed result
- **WHEN** a response is empty, missing required permissions, unknown, restricted or failed
- **THEN** the application reports that distinct state and never treats it as granted
- **AND** permission failure prevents device control and consumption requests

### Requirement: Denial and settings results are truthful
The application SHALL offer explicit settings navigation for permanent denial or system restriction and SHALL NOT automatically open settings.

#### Scenario: Settings cannot open
- **WHEN** the platform returns false or throws while opening settings
- **THEN** the application reports failure with retry or manual guidance rather than claiming it opened

### Requirement: Foreground return refreshes relevant permissions
Permission and scanner screens SHALL re-check relevant state when returning to the foreground without automatically requesting again. Scanner startup SHALL wait for permission and foreground availability.

#### Scenario: User changes permission in settings
- **WHEN** the user returns after changing permission
- **THEN** current state is reflected without restarting the app

### Requirement: C5a preserves records and limits unsupported control
The runtime, production adapter and BLE transport SHALL block iOS Zhuli start/stop before control-side HTTP or BLE operations. Existing sessions, including expired or uncertain sessions, SHALL remain until existing explicit local recovery actions apply. Unavailability SHALL NOT be reported as successful stop.

### Requirement: Unimplemented notifications are not requested or promised
The application SHALL remove unused notification permission declarations and prompts, disable the permission-handler notification macro, and make no status notification promise. Existing OS grants SHALL NOT be actively revoked. This requirement does not add notification delivery.
