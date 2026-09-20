## 1. Session model and persistence

> 下方 1–6 为历史完成记录。2026-09-19 热水规则已被 M1-B 替换；最新测试与验收见 P_PLAN/PLAN.md 和根目录 bug.md，不将历史轮询断言视为当前行为。

- [x] 1.1 Reconcile the existing uncommitted hotwater changes with the approved state-machine design and preserve unrelated user work.
- [x] 1.2 Implement versioned hotwater session phases (`preparing`, `starting`, `uncertain`, `active`) and optional startup order identity in the runtime model.
- [x] 1.3 Make session decoding accept legacy version 1 data conservatively as `uncertain`, reject malformed data safely, and cover the migration codec with tests.
- [x] 1.4 Add one runtime-owned cleanup path that removes the persisted session, secure `isn`, and polling timers while guarding against disposal and session replacement.

## 2. Safe hotwater startup and recovery

- [x] 2.1 Complete the adapter progress contract for Fake and real Zhuli adapters, including a durable command-dispatch boundary recorded before the BLE start write is attempted.
- [x] 2.2 Update Zhuli and Shower798 startup transitions so pre-dispatch failures roll back locally, while post-dispatch failures retain an `uncertain` session.
- [x] 2.3 Fix nullable-session and missing-cleanup compile paths, then guard every asynchronous transition with session ID, account authorization epoch, and disposal checks.
- [x] 2.4 Update restart and foreground-resume recovery so only `active`/`uncertain` sessions poll, while `preparing`/`starting` sessions are safely cleared without claiming device state.
- [x] 2.5 Preserve known `isn` and order identity through uncertain recovery, keep polling read-only, and clear the session only after confirmed stop, terminal reconciliation, or explicit local clear.

## 3. User-facing local recovery

- [x] 3.1 Add a clear-session runtime action for legacy, uncertain, or credentialless sessions that never calls a device control endpoint.
- [x] 3.2 Add a confirmation flow in the hotwater detail surface, with copy that distinguishes local record removal from device shutdown and supports cancellation.
- [x] 3.3 Ensure the home/ongoing state, stop button state, polling timers, and secure credential cleanup update consistently after explicit local clear or successful stop.

## 4. Regression coverage

- [x] 4.1 Add a runtime test for an out-of-range/scan failure before command dispatch: no persisted session remains, polling is stopped, the actual retryable error is shown, and a second start is possible.
- [x] 4.2 Add a runtime test for a lost start response after command dispatch: `uncertain` and `isn` persist, read-only polling resumes, and the session is not falsely reported as stopped.
- [x] 4.3 Add tests for legacy version 1 and missing-`isn` sessions, including confirmation/cancellation of local clear and the absence of device start/stop calls.
- [x] 4.4 Add tests for known startup order matching, same-device baseline filtering, account changes, default-system changes, obsolete poll responses, and mutually exclusive polling.
- [x] 4.5 Add adapter contract tests for progress ordering and the pre-write command-dispatch boundary in both Fake and real test doubles.
- [x] 4.6 Add widget coverage for the pending state, local-clear confirmation, neutral local-clear result, and retryable post-failure UI.

## 5. Android release validation

- [x] 5.1 Fix the release script to read `assets/public/version.json`, report both paths on version mismatch, and retain explicit formal-signing checks for `android/key.properties` and its keystore.
- [x] 5.2 Make the direct release APK path and release script distinguish local debug-signed verification artifacts from formally signed distribution artifacts.
- [x] 5.3 Add or update validation coverage for aligned/mismatched versions, missing signing configuration, and Dart compile failures before artifact reporting.
- [x] 5.4 Remove the current Dart build blockers and verify that `flutter analyze` reaches zero diagnostics before invoking Gradle packaging.

## 6. Verification and handoff

- [x] 6.1 Run formatter, `flutter analyze`, the full Flutter test suite, `git diff --check`, and OpenSpec validation for the completed change.
- [x] 6.2 Run `flutter build apk --release` and record the APK path, package ID, version, signing mode, and checksum; if formal signing is unavailable, label the output as local verification.
- [x] 6.3 Run the release-script validation path and document any expected signing-environment prerequisite separately from source/build failures.
