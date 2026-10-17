## Requirements (updated by approved C6a 1A/2A/3A)

### Requirement: Candidate and published metadata are separate
The release tool SHALL read the candidate version from pubspec and SHALL NOT require it to match or overwrite the published stable manifest. Both stable manifest copies SHALL agree. A compatible new manifest SHALL only be prepared after the release is public, non-prerelease, and its APK bytes match the verified candidate.

### Requirement: Release requires formal signing
Relative storeFile SHALL resolve against android/ consistently in Gradle and tooling using Java Properties semantics. Missing or incomplete signing SHALL reject release tasks without affecting independent Debug builds. There SHALL be no release-to-Debug signing fallback or automatic credential migration.

### Requirement: Verify actual upgrade inputs and outputs
The tool SHALL inspect historical APK hashes, application IDs, certificates, ABIs and version codes within the supplied reviewed scope, including all three published 2.1.4 variants. The candidate code SHALL exceed all inspected codes. New universal APK metadata SHALL match candidate version/code, original identity/certificate, both supported ABIs, and non-debuggable status.

### Requirement: Report only fresh verified artifacts
Analysis and full Flutter tests SHALL precede packaging. Only fresh expected outputs SHALL be reported with source revision, tooling, size and SHA-256. AAB SHALL be optional and verified independently. Missing validation tools, stale outputs or any failed check SHALL prevent a successful report. Reports SHALL NOT claim installation or release success.

### Requirement: Distribution remains separately authorized
Ordinary pushes SHALL run CI without formal keys, publication or stable-manifest mutation. Formal candidate construction, upgrade installation and publication require their separately confirmed scope. Existing releases and local user data SHALL remain intact.
