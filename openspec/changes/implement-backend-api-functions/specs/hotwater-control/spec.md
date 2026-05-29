## ADDED Requirements

### Requirement: Hot water start uses verified session, API, and BLE flow

The system SHALL start hot water from the new UI only after validating required phone/device/session inputs and required BLE permissions. The start flow MUST use the documented Zhuli login/session behavior, device lookup, BLE handshake, optional rate/history synchronization, order creation, BLE start command, start confirmation, and `last_isn`/order persistence.

#### Scenario: Start hot water succeeds

- **WHEN** the user taps "开热水" with valid login/session, device ID, BLE permissions, and nearby target device
- **THEN** the system completes the documented start lifecycle, stores `last_device_id`, `last_isn`, and `last_order_id`, and reports a running/success state

#### Scenario: Start hot water requires login

- **WHEN** the user taps "开热水" without a usable hot-water session and without enough credentials to log in
- **THEN** the system does not start BLE or create an order and shows a login-required state

#### Scenario: Start hot water lacks BLE permission

- **WHEN** the user taps "开热水" without required BLE or nearby-device permissions
- **THEN** the system requests or reports the missing permission before attempting BLE scan/connect

### Requirement: Hot water stop requires current app session state

The system SHALL stop hot water from the new UI only when a cached session and matching `last_isn` exist. If `last_isn` is missing, the system MUST NOT attempt an unreliable stop and MUST explain that only this app's current opened hot-water session can be closed.

#### Scenario: Stop hot water succeeds

- **WHEN** the user taps "关热水" with valid session, device ID, and `last_isn`
- **THEN** the system runs the documented end-command BLE flow, confirms end consume, clears `last_device_id`, `last_isn`, and `last_order_id`, and reports stopped/success state

#### Scenario: Stop hot water is unavailable

- **WHEN** the user taps "关热水" and no valid `last_isn` is stored
- **THEN** the system blocks the action and shows that only the current app-started hot-water session can be closed

### Requirement: Hot water history is sourced from verified API behavior

The system SHALL show hot-water history using the documented `consume/list_record_by_staffid` behavior and cached Zhuli session state. History loading failures MUST be visible without breaking the rest of the app.

#### Scenario: History loads

- **WHEN** the user opens the order/history UI with a valid hot-water session
- **THEN** the system requests recent hot-water records and displays returned records in the order UI

#### Scenario: History fails

- **WHEN** the history request fails or returns a sign/session error
- **THEN** the system shows an error or login-required state and records the issue in local logs

### Requirement: Hot water widget and legacy flows remain compatible

The system SHALL preserve existing widget, foreground service, and legacy Activity hot-water behavior while adding the new UI entry points.

#### Scenario: Widget flow still works

- **WHEN** the user starts or stops hot water from the existing widget path
- **THEN** the widget continues using the existing action runner behavior without regression from the new UI integration
