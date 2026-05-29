## ADDED Requirements

### Requirement: Home task area reflects live runtime work
The system SHALL render the home "进行中" area from runtime task state instead of static placeholder content.

#### Scenario: No active task exists
- **WHEN** the runtime has no active hot-water or washer task
- **THEN** the home task area shows a single empty state labeled "无任务"

#### Scenario: A hot-water task is active
- **WHEN** the runtime has an active hot-water task
- **THEN** the home task area shows a compact task entry with task type, elapsed time or duration, and a tap target that opens the hot-water detail page

#### Scenario: A washer task is active
- **WHEN** the runtime has an active washer task
- **THEN** the home task area shows a compact task entry with washer order information, remaining time or countdown when available, and a tap target that opens the washer order detail page

#### Scenario: Multiple tasks are active
- **WHEN** more than two tasks are active
- **THEN** the home task area shows the highest-priority tasks and collapses the rest into a more entry

### Requirement: QR scans route by code type
The system SHALL classify scanned QR codes and route them to the matching workflow instead of always entering the washer flow.

#### Scenario: Washer code is scanned
- **WHEN** a scanned QR code is identified as a washer code
- **THEN** the system opens the washer flow entry point

#### Scenario: Drinking-water code is scanned
- **WHEN** a scanned QR code is identified as a drinking-water code
- **THEN** the system opens the drinking-water entry point or a clearly labeled unsupported state, and does not open the washer flow

#### Scenario: Unknown code is scanned
- **WHEN** a scanned QR code cannot be classified
- **THEN** the system shows an error state and does not navigate to a device workflow

### Requirement: Device list supports refresh and local editing
The system SHALL provide a device list that can be refreshed and edited from the device page.

#### Scenario: User pulls to refresh
- **WHEN** the user pulls down on the device list
- **THEN** the system refreshes the list and updates the latest refresh time

#### Scenario: User renames a device
- **WHEN** the user edits a device name
- **THEN** the device list updates the displayed local alias and keeps the device number on one line with truncation if needed

#### Scenario: User deletes a device
- **WHEN** the user deletes a device
- **THEN** the device is removed from the visible list and the empty state is shown when no devices remain

### Requirement: Account cards open dedicated account flows
The system SHALL move account login and device binding inputs out of the home page and into dedicated account screens.

#### Scenario: User opens a hot-water account card
- **WHEN** the user taps the 住理生活 account card
- **THEN** the system opens a dedicated account screen containing login, status, and hot-water device code binding actions

#### Scenario: User opens a U净 account card
- **WHEN** the user taps the U净 account card
- **THEN** the system opens a dedicated account screen containing the same action structure as the 住理生活 account screen

#### Scenario: User is logged in
- **WHEN** an account has a cached login session
- **THEN** the account card shows the account state and hides inline login fields

#### Scenario: User is logged out
- **WHEN** an account has no session
- **THEN** the account card shows only the logged-out state and an entry button

### Requirement: More options open a dedicated page
The system SHALL keep the more-options actions collapsed until the user opens the more-options page.

#### Scenario: User opens more options
- **WHEN** the user taps the more-options entry
- **THEN** the system navigates to a separate page that exposes permission check, logs, diagnostics, and import/export actions

#### Scenario: More options are collapsed by default
- **WHEN** the profile page first opens
- **THEN** the more-options actions are not expanded inline

