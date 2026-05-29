## ADDED Requirements

### Requirement: Runtime actions are separated from static previews

The system SHALL instantiate real service-backed actions only from runtime app entry points. Compose previews, preview helper data, and design-only screens MUST use fake state and MUST NOT call network, BLE, scanner, payment, foreground-service, token, or SharedPreferences-mutating code.

#### Scenario: Preview renders without real services

- **WHEN** a Compose preview or design-only state is rendered
- **THEN** the screen displays fake data without invoking real service adapters

#### Scenario: Runtime screen uses real actions

- **WHEN** `MainActivity` launches the app normally
- **THEN** the Compose screens receive runtime state/actions capable of calling verified service adapters

### Requirement: User actions expose explicit UI state

The system SHALL expose explicit state for idle, loading, success, failure, permission-required, login-required, and payment-in-progress outcomes. Runtime buttons MUST be disabled or guarded when their action would conflict with the current state.

#### Scenario: Duplicate action is blocked

- **WHEN** a user taps a runtime action while the same action is already loading
- **THEN** the system prevents a second concurrent execution and keeps the current state visible

#### Scenario: Failure is visible

- **WHEN** a runtime service action fails
- **THEN** the system shows a user-readable failure state and keeps enough detail in logs for local debugging

### Requirement: Static data is replaced by runtime state where services exist

The system SHALL replace static account, order, washer-device, and hot-water status values with runtime state when corresponding verified service data exists. Unsupported or uncaptured domains MUST remain visibly unavailable rather than pretending to be functional.

#### Scenario: Runtime order state is available

- **WHEN** the app has fetched verified order or current-order data
- **THEN** the order UI displays that runtime data instead of hardcoded prototype rows

#### Scenario: Unsupported drinking-water action is requested

- **WHEN** the user reaches a drinking-water action whose endpoint is not captured
- **THEN** the system does not call washer endpoints and instead shows that the function is not ready

### Requirement: Device list is a local shortcut list

The system SHALL manage the in-app device list as local shortcuts. Adding a device MUST save local metadata such as alias, QR URL or `cd`, device type, last known state, and sort order. Editing or deleting a device MUST change only local app data and MUST NOT call official account binding, rename, unbind, or delete APIs.

#### Scenario: Local washer shortcut is refreshed

- **WHEN** the user opens or refreshes a saved washer shortcut
- **THEN** the system reuses the saved QR URL with the verified washer scan flow and updates local state from the response

#### Scenario: Local device is renamed or deleted

- **WHEN** the user edits the name or deletes a saved device shortcut
- **THEN** the system updates only local storage and does not affect official account device data

### Requirement: Disagreement points require review before implementation proceeds

The implementation workflow MUST pause for user review when a product or API decision is not determined by existing docs or source code.

#### Scenario: Missing endpoint decision

- **WHEN** implementation reaches a feature with no verified endpoint, such as Ujing drinking-water ordering
- **THEN** the implementer records the issue and asks the user to choose a path before coding that feature
