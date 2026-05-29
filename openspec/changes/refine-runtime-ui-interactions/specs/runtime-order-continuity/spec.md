## REMOVED Requirements

### Requirement: Legacy hot-water activity remains launchable
**Reason**: The user no longer wants the old hot-water entry to remain a visible launch target; the Compose runtime and profile/account flows now own the user-facing entry points.
**Migration**: Move all user-facing hot-water login and device binding actions into the dedicated account screen and retire the legacy activity from the public UI path.

#### Scenario: Legacy activity is no longer a visible entry
- **WHEN** the Android manifest and launcher entry points are inspected after this change
- **THEN** the user-facing hot-water entry is provided by the Compose runtime instead of the legacy activity

#### Scenario: Existing internal code remains temporarily available
- **WHEN** internal references still need the legacy implementation during migration
- **THEN** the code may remain only as an internal compatibility path and not as a user-facing launch target
