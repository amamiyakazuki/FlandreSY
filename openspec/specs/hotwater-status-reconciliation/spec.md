# hotwater-status-reconciliation Specification

## Purpose
定义热水会话的持久化、订单基线核对、生命周期轮询和证据不足时的状态保留。明确应用重启、一小时补查、账号变化和默认系统切换时的处理，防止把网络失败或不相关订单误判为本次会话结束。
## Requirements
### Requirement: Hotwater sessions survive application restart
The runtime SHALL capture a same-device order baseline before starting Zhuli hotwater and persist the active session with its account, system, device, start time and baseline. It SHALL restore the session after restart and immediately reconcile it using read-only queries. Stop credentials SHALL be stored in secure storage.

#### Scenario: Application restarts during a session
- **WHEN** an unfinished persisted session is restored
- **THEN** the app retains its pending state, immediately checks its original account and device, and resumes foreground polling every 10 seconds

#### Scenario: Application is suspended or terminated
- **WHEN** the application cannot execute foreground polling
- **THEN** it preserves the session and immediately reconciles it on its next start or foreground resume

### Requirement: Read-only reconciliation determines session completion
For Zhuli, the runtime SHALL infer completion from a same-device order absent from the baseline and dated after the session start. For Shower798, it SHALL retain the existing read-only idle-state query. It SHALL NOT use start or stop operations as polling probes. Successful explicit stop SHALL clear the session.

#### Scenario: New consumption record appears
- **WHEN** a Zhuli poll finds a same-device non-baseline order with a parseable time later than the session start
- **THEN** it infers session completion and clears the corresponding ongoing state

#### Scenario: Session reaches one hour
- **WHEN** a persisted session reaches one hour
- **THEN** the app requests another reconciliation and does not clear the session solely because local time elapsed

### Requirement: Hotwater polling represents unknown status honestly
The runtime SHALL preserve an explicit pending or unknown state when queries fail or order evidence is insufficient. Polls SHALL be mutually exclusive and discard responses from obsolete sessions. Default-system changes SHALL NOT change the active session's control target.

#### Scenario: No live status and no terminal evidence
- **WHEN** queries fail, orders remain unchanged, or records lack a usable identifier or timestamp
- **THEN** the UI shows an unknown or awaiting-confirmation state and does not claim that hotwater stopped

#### Scenario: Account or unrelated records change
- **WHEN** the logged-in account differs from the persisted session account, or only other devices' orders, list order or missing old records change
- **THEN** the app preserves the session and does not query using a different account or infer completion from those changes
