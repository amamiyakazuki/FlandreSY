## ADDED Requirements

### Requirement: Home status cards show actionable state only
Home status cards SHALL omit generic instructional or warning copy that does not correspond to an available action, while retaining actionable errors and verified service status.

#### Scenario: Hotwater card has no message
- **WHEN** the hotwater card has no actionable error or verified status message
- **THEN** it does not display the generic text about viewing current status and executing operations

#### Scenario: Hotwater card has an actionable error
- **WHEN** a service operation returns an actionable error
- **THEN** the card displays the error without truncating its meaning
