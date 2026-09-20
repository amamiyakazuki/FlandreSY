# hotwater-status-reconciliation Specification

## Purpose
定义用户确认的热水手动控制、40 分钟恢复显示和独立订单刷新规则。2026-09-19 起替代旧订单基线、10 秒轮询及一小时补查判定；保持协议调用与本地显示的区别。

## Requirements

### Requirement: Hotwater sessions survive application restart
The runtime SHALL persist the account, system, device, command-dispatch time, startup phase and available stop credential. On application startup or foreground resume, an active or uncertain session at most 40 minutes old SHALL restore the local running display; a session older than 40 minutes SHALL reset to the initial ready-to-start display and request the original account's Zhuli consumption history when that account is available. This reset SHALL NOT send a device stop command or claim that the device physically stopped. Preparing or starting sessions that have not reached command dispatch SHALL be cleared as incomplete attempts.

#### Scenario: Restore within or exactly at 40 minutes
- **WHEN** a session that may have started is restored no more than 40 minutes after command dispatch
- **THEN** the app shows hotwater in use even if its local stop credential is missing and leaves both control buttons available

#### Scenario: Restore after 40 minutes
- **WHEN** a session is restored more than 40 minutes after command dispatch
- **THEN** the app clears the local session, shows ready to start, and refreshes available Zhuli consumption history without issuing device controls

#### Scenario: Order refresh fails after expiry
- **WHEN** the refresh fails after the local display was reset
- **THEN** the app keeps its ready-to-start display and cached orders, exposes the refresh failure, and permits another manual operation

#### Scenario: Runtime remains in foreground
- **WHEN** the app stays open beyond 40 minutes
- **THEN** no periodic 10-second or one-hour status-reconciliation timer changes its running display; the time rule applies on the next recovery event

#### Scenario: Restore occurs while a command is executing
- **WHEN** a foreground recovery is requested while a start or stop is in flight
- **THEN** recovery waits for the command and evaluates the resulting session instead of clearing its intermediate state

### Requirement: Manual hotwater controls remain available
The home and detail start and stop buttons SHALL accept taps regardless of running, pending, idle or loading display state. Commands SHALL execute sequentially, coalesce consecutive identical requests and reject queued requests whose account authorization or target has changed. Login and device prerequisites SHALL produce feedback rather than silent rejection. Start SHALL NOT depend on a consumption-history baseline. A repeated start for the same account and device with an active or uncertain session SHALL return feedback without repeating the protocol or replacing the session, dispatch time or stop credential. Restore operations SHALL NOT break in-flight duplicate coalescing; stop and explicit local clear SHALL remain ordering barriers.

#### Scenario: Stop clicked during start
- **WHEN** the user clicks stop while start is executing
- **THEN** stop waits for start to finish and uses its resulting control information; consecutive duplicate taps do not dispatch duplicate commands

#### Scenario: Start clicked while running
- **WHEN** the user starts again after a prior start completes
- **THEN** the adapter receives no additional start and the original session, credential and recovery reference are retained

#### Scenario: Dispatch result or persistence is uncertain
- **WHEN** the command dispatch stage was reached but confirmation or subsequent persistence failed, and the user starts again
- **THEN** the in-memory uncertain session prevents another start, retains available stop credentials and reports uncertainty rather than suggesting a blind retry

#### Scenario: Start stop start in quick succession
- **WHEN** the user requests start, stop and start in that order
- **THEN** commands preserve that order; the final start executes only after the preceding session has been successfully stopped and cleared

#### Scenario: Repeated start fails before dispatch
- **WHEN** a new start attempt fails before its device command is dispatched
- **THEN** an earlier session and its credential are retained, or the failed temporary session is removed if no earlier session existed

#### Scenario: Stop has no local Zhuli session or credential
- **WHEN** a logged-in user clicks stop without local Zhuli control information
- **THEN** the app refreshes account consumption history, reports the refresh result and does not block the controls or report a successful physical stop

#### Scenario: Stop has a credential
- **WHEN** the user clicks stop with valid local Zhuli control information
- **THEN** the app uses the existing stop protocol, clears the local session after success and refreshes consumption history

#### Scenario: Shower798 stop without local session
- **WHEN** a logged-in Shower798 user with a selected device clicks stop
- **THEN** the existing device stop endpoint is used even without a local hotwater session

### Requirement: Order queries do not determine hotwater completion
Queries SHALL update and persist consumption history only. A matching order, a completed status, an empty result or a query failure SHALL NOT change the running display or delete control information. Concurrent identical history requests SHALL be coalesced, and results obsolete after session replacement, account authorization changes, a newer control operation or runtime disposal SHALL be discarded. Shower798 SHALL NOT query Zhuli history or use device-idle polling to determine hotwater completion.

#### Scenario: Matching completed order appears
- **WHEN** a query returns the current order with a completed status
- **THEN** history is updated and the existing local running display is preserved

#### Scenario: Old history response arrives after a new operation
- **WHEN** a history response belongs to an older session or authorization generation
- **THEN** it is discarded without overwriting the new history or hotwater state

#### Scenario: Stop error notice expires
- **WHEN** a failed stop's temporary notice expires
- **THEN** only that notice is cleared and an ongoing hotwater title remains running

### Requirement: User can clear an unreconciled local session
A user-confirmed local clear SHALL be serialized with control and restore operations. The session SHALL be rechecked when the clear executes. Persisted session deletion SHALL precede credential deletion so a settings failure does not remove the credential of a retained session. A successful local clear SHALL remove only local state and SHALL NOT claim device shutdown.

#### Scenario: Clear during an in-flight start
- **WHEN** an earlier confirmation reaches the runtime while a start is in flight
- **THEN** clear waits for the command and rechecks eligibility, leaving a successfully started session with its credential intact

#### Scenario: Persisted session deletion fails
- **WHEN** local session storage rejects deletion
- **THEN** the app retains the local session and its stop credential and reports the local cleanup failure
