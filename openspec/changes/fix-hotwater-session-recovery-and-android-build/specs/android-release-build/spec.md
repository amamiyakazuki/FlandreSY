## ADDED Requirements

### Requirement: Android release metadata uses one canonical version manifest
The Android release validation SHALL compare the marketing version in `pubspec.yaml` with the version in `assets/public/version.json`, which is the project's canonical bundled and remote update manifest. The validation SHALL fail before Gradle execution when the values differ and SHALL identify both paths in the error.

#### Scenario: Release metadata is aligned
- **WHEN** the marketing versions in `pubspec.yaml` and `assets/public/version.json` match
- **THEN** release validation proceeds to signing and build checks

#### Scenario: Release metadata is stale or mismatched
- **WHEN** the two canonical version values differ
- **THEN** validation stops before building and reports the values and file paths that must be synchronized

### Requirement: Android release validation distinguishes local verification from formal signing
The project SHALL provide a direct local release APK path that can compile and package with the configured debug fallback when no release keystore is present, while the formal release script SHALL require complete `android/key.properties` and an existing referenced keystore. Missing or incomplete signing configuration SHALL produce an actionable pre-build error and SHALL not be presented as a formally distributable release.

#### Scenario: Local APK verification without a release keystore
- **WHEN** a developer runs the direct release APK build without `android/key.properties`
- **THEN** the project may use the configured debug signing fallback and the result is identified as local verification output

#### Scenario: Formal release signing configuration is missing
- **WHEN** the release script runs without a complete `android/key.properties` or its referenced keystore
- **THEN** the script stops before artifact generation and reports the missing signing requirement

### Requirement: Release APK compilation is verified before artifact reporting
The release workflow SHALL run static analysis and regression tests before reporting a successful APK build, and the APK build SHALL pass the Flutter compilation stage before Gradle packaging and signing are considered successful. Dart compile failures SHALL be reported separately from Gradle, R8, and signing failures.

#### Scenario: Dart source is not compilable
- **WHEN** `flutter analyze` or the Flutter release compilation reports a Dart error
- **THEN** the workflow fails without claiming that APK packaging or signing succeeded and identifies the source diagnostics

#### Scenario: APK build completes
- **WHEN** analysis, tests, Flutter release compilation, Gradle packaging, and configured signing all succeed
- **THEN** the workflow reports the APK path, application version, application ID, signing mode, and checksum
