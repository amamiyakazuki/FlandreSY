## ADDED Requirements

### Requirement: Selecting an account system does not change the default before login
The account hub SHALL navigate to the selected account detail page without changing the home default bathing system.

#### Scenario: User opens an account detail page
- **WHEN** the user selects Zhuli or Shower798 from the account hub
- **THEN** the app opens that detail page and preserves the existing home default until login succeeds or the user explicitly selects the option

### Requirement: Successful login selects the system by default
Each bathing-system account page SHALL automatically select its system as the home default after successful login, while allowing the user to clear or change that choice.

#### Scenario: Zhuli login succeeds
- **WHEN** Zhuli authentication completes successfully
- **THEN** the Zhuli page shows the default-system option selected and the home preference is persisted as Zhuli

#### Scenario: User clears the default option
- **WHEN** the user clears the selected default-system option
- **THEN** the home preference is not changed implicitly by subsequent visits to the account page

### Requirement: Ujing login does not select a bathing system
The Ujing account flow SHALL never change the home bathing-system preference.

#### Scenario: Ujing login succeeds
- **WHEN** Ujing authentication completes successfully
- **THEN** the Ujing account is updated without changing the Zhuli or Shower798 home preference
