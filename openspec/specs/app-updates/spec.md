# App updates

## Requirements

### Requirement: Installation metadata is authoritative
About and update flows SHALL use the shared real package metadata reader. Missing or malformed versions SHALL be unknown, never a hardcoded old version. Build number and package identity SHALL constrain direct Android update actions; Debug is an independent installation.

### Requirement: Updates are platform-specific
Android production packages MAY open the repository universal APK only when a valid stable manifest reports an appropriate version and strictly higher build number. Lower marketing versions SHALL NOT be offered as updates. iOS and unsupported platforms SHALL report no channel and SHALL NOT fall back to Android links.

### Requirement: Preserve legacy manifest compatibility
Existing top-level fields and paths SHALL remain available for old clients. New clients SHALL parse old manifests but only offer release information when build compatibility is unknown. Extended schema 2 SHALL consistently identify the Android version/build/download and iOS unavailability. Invalid types, versions, schemas or links SHALL fail without claiming latest status.

### Requirement: External navigation is truthful and recoverable
Only approved HTTPS repository release links SHALL be opened. False/exception results SHALL show retryable feedback. Pending taps SHALL be suppressed, late results after disposal ignored, and successful navigation SHALL only claim the link opened. Long notes and large text SHALL remain scrollable.
