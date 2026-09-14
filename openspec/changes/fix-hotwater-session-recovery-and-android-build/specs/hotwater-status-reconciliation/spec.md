## MODIFIED Requirements

### Requirement: Hotwater sessions survive application restart
The runtime SHALL capture a same-device order baseline before starting Zhuli hotwater and persist a session with its account, system, device, start time, baseline, explicit startup phase, and optional order identifier. The session SHALL distinguish `preparing`, `starting`, `uncertain`, and `active` states. Stop credentials SHALL be stored in secure storage before they are needed for an explicit stop. The runtime SHALL restore version 1 and current session formats safely after restart and immediately reconcile only sessions that may have reached the device-control boundary.

#### Scenario: Application restarts during an active or uncertain session
- **WHEN** an unfinished persisted session in `active` or `uncertain` phase is restored
- **THEN** the app retains the original account, system, device, and order binding, immediately performs read-only reconciliation, and resumes foreground polling every 10 seconds

#### Scenario: Application is suspended or terminated
- **WHEN** the application cannot execute foreground polling
- **THEN** it preserves the session and immediately reconciles it on its next start or foreground resume

#### Scenario: Application restores a preparing or starting session
- **WHEN** a persisted session is in `preparing` or `starting` phase and no device start command has crossed the durable dispatch boundary
- **THEN** the app removes the local session and stop credential, does not start polling, and exposes a retryable startup failure without claiming that hotwater was running

#### Scenario: Application restores a legacy version 1 session
- **WHEN** a persisted version 1 session has no startup phase or order identifier
- **THEN** the app conservatively restores it as an uncertain session, preserves its original identity, and exposes read-only reconciliation plus a user-confirmed local-clear option

### Requirement: Read-only reconciliation determines session completion
For Zhuli, the runtime SHALL infer completion from a same-device order absent from the baseline and dated after the session start, or from the persisted startup order identifier when one is known. For Shower798, it SHALL retain the existing read-only idle-state query. It SHALL NOT use start or stop operations as polling probes. A start failure before the durable dispatch boundary SHALL clear the local startup session; a failure after that boundary SHALL preserve an uncertain session. Successful explicit stop SHALL clear the session.

#### Scenario: New consumption record appears
- **WHEN** a Zhuli poll finds the known startup order, or a same-device non-baseline order with a parseable time later than the session start
- **THEN** it infers session completion and clears the corresponding ongoing state

#### Scenario: Session reaches one hour
- **WHEN** a persisted session reaches one hour
- **THEN** the app requests another reconciliation and does not clear the session solely because local time elapsed

#### Scenario: Device is out of Bluetooth range before command dispatch
- **WHEN** scanning, connecting, handshaking, or creating the startup order fails before the durable dispatch boundary
- **THEN** the app removes the temporary session and secure stop credential, stops its polling timers, shows the actual retryable error, and allows a new start attempt

#### Scenario: Startup response is lost after command dispatch
- **WHEN** the device start command has been attempted and the response or confirmation is lost
- **THEN** the app preserves the session as `uncertain`, keeps the available stop credential, and performs only read-only reconciliation on retry, restart, or foreground resume

### Requirement: Hotwater polling represents unknown status honestly
The runtime SHALL preserve an explicit pending or unknown state when queries fail or order evidence is insufficient. Polls SHALL be mutually exclusive, bound to the session ID and account authorization epoch, and discard responses from obsolete sessions. Default-system changes SHALL NOT change the active session's control target. A local-clear action SHALL be available for sessions whose state cannot be safely reconciled.

#### Scenario: No live status and no terminal evidence
- **WHEN** queries fail, orders remain unchanged, or records lack a usable identifier or timestamp
- **THEN** the UI shows an unknown or awaiting-confirmation state and does not claim that hotwater stopped

#### Scenario: Account or unrelated records change
- **WHEN** the logged-in account differs from the persisted session account, or only other devices' orders, list order, or missing old records change
- **THEN** the app preserves the session and does not query using a different account or infer completion from those changes

#### Scenario: Obsolete poll response arrives
- **WHEN** a poll response returns after logout, session replacement, or runtime disposal
- **THEN** the response is discarded without changing the current session, history, or ongoing-state UI

### Requirement: User can clear an unreconciled local session
The runtime SHALL provide a user-confirmed local-clear operation for a legacy, uncertain, or credentialless session that cannot be safely stopped or automatically reconciled. The operation SHALL remove the persisted session, secure stop credential, and polling timers without calling a device start/stop endpoint, and SHALL state that only the App's local record was cleared.

#### Scenario: User confirms local clear
- **WHEN** the user confirms clearing an unreconciled session
- **THEN** the app clears local session state and secure credentials, removes the item from the ongoing list, stops polling, and shows a neutral local-clear result

#### Scenario: User cancels local clear
- **WHEN** the user dismisses the confirmation
- **THEN** the session, credentials, polling, and pending status remain unchanged
