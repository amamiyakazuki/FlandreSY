## ADDED Requirements

### Requirement: Legacy hot-water activity remains launchable
The system SHALL keep `LegacyHotwaterActivity` registered as an Android activity while legacy hot-water code remains present and referenced.

#### Scenario: Legacy activity is declared
- **WHEN** the Android manifest is inspected after this change
- **THEN** it contains an activity declaration for `LegacyHotwaterActivity`

#### Scenario: Compose launcher remains primary
- **WHEN** the app is launched from the device launcher
- **THEN** `MainActivity` remains the launcher entry point

### Requirement: Washer order detail uses runtime order data
The system SHALL render washer order detail from the current runtime washer order or a freshly loaded order detail, not hard-coded sample values.

#### Scenario: Current order exists
- **WHEN** the user opens the order detail page and runtime has a current washer order
- **THEN** the page displays that order's id, device number, status, amount, remaining time or countdown when available, and related action controls

#### Scenario: No current order exists
- **WHEN** the user opens the order detail page and runtime has no current washer order
- **THEN** the page does not display fake order data and instead presents an empty or guidance state

### Requirement: Alipay return status is respected
The system SHALL interpret the Alipay SDK `resultStatus` before presenting payment success or updating payment action state.

#### Scenario: Alipay returns success
- **WHEN** `payV2()` returns `resultStatus=9000`
- **THEN** the system refreshes the server order detail and reports payment returned successfully with the refreshed server status

#### Scenario: Alipay returns cancel or failure
- **WHEN** `payV2()` returns a cancelled, failed, pending, empty, or unknown result status
- **THEN** the system does not claim payment success and keeps the UI message aligned with the SDK result and refreshed order status when available

### Requirement: Washer order is restored after app restart
The system SHALL attempt to recover the active Ujing washer order after startup when a cached Ujing session exists.

#### Scenario: Running order exists
- **WHEN** the app starts with a cached Ujing session and Ujing reports a last-running or running washer order
- **THEN** runtime state is hydrated with that order detail so detail, start, and stop UI reflect the real order state

#### Scenario: No running order exists
- **WHEN** the app starts with a cached Ujing session and Ujing reports no active washer order
- **THEN** runtime state remains logged in without inventing a current order

### Requirement: Washer control actions are status guarded
The system SHALL only call Ujing washer `control/start` and `control/stop` from valid order states.

#### Scenario: Start is requested for a paid order
- **WHEN** the current order is in a paid/startable state
- **THEN** the system may call `control/start` and refreshes order detail after the request

#### Scenario: Start is requested for an invalid order
- **WHEN** the current order is unpaid, running, completed, cancelled, missing, or otherwise not startable
- **THEN** the system does not call `control/start` and reports that the order cannot be started in its current state

#### Scenario: Stop is requested for a running order
- **WHEN** the current order is starting or running
- **THEN** the system may call `control/stop` and refreshes order detail after the request

#### Scenario: Stop is requested for an invalid order
- **WHEN** the current order is unpaid, merely paid, completed, cancelled, missing, or otherwise not stoppable
- **THEN** the system does not call `control/stop` and reports that the order cannot be stopped in its current state

### Requirement: Payment does not implicitly start washer
The system SHALL keep payment completion separate from washer start unless a user-selected auto-start option is explicitly enabled.

#### Scenario: Payment succeeds without auto-start
- **WHEN** payment returns successfully and no explicit auto-start option is enabled
- **THEN** the system refreshes the order detail and shows the manual start action when the server order is paid/startable

#### Scenario: Manual start remains user initiated
- **WHEN** the server order becomes paid/startable after payment
- **THEN** `control/start` is only called after the user invokes the start action or an explicitly enabled auto-start option performs that action
