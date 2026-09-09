## ADDED Requirements

### Requirement: Account hub routes to system-specific account pages
The account hub SHALL present each supported account system and route selection to that system's dedicated account page. Selecting a system SHALL NOT itself change the home default bathing system; the account page SHALL expose the default-system choice and apply it only after successful login or explicit user selection.

#### Scenario: User selects a supported system
- **WHEN** the user taps a system in the account hub
- **THEN** the app opens that system's account page and leaves the home preference unchanged

#### Scenario: User opens the account hub
- **WHEN** the user opens the account hub
- **THEN** Zhuli, Shower798 and Ujing appear as staggered circular App-image entries with readable names, each opening its dedicated account page
- **AND** narrow screens and enlarged text remain scrollable without overlapping entries

#### Scenario: User returns from an account page
- **WHEN** the user taps back from a system-specific account page
- **THEN** the app returns to the account hub without losing the existing home preference
