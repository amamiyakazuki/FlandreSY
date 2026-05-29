## Why

Recent review found several runtime regressions and incomplete integrations around the Compose app handoff: the legacy hot-water activity entry can no longer be launched normally, washer order detail still shows sample data, payment return handling can mislabel failed or cancelled Alipay flows, and active washer orders are not restored after app restart.

This change is needed before further UI polishing so the already-captured Ujing washer workflow remains truthful, recoverable, and compatible with the existing hot-water implementation.

## What Changes

- Restore a normal manifest entry for `LegacyHotwaterActivity` so the old hot-water UI and its dependent flows remain reachable unless explicitly removed in a later deprecation change.
- Replace static washer order detail content with runtime-backed current order/detail data, including payment, manual start, stop, cancel, status, amount, device, and time fields where available.
- Handle Alipay SDK `payV2()` results by `resultStatus` before presenting payment success or refreshing into a paid state.
- Add runtime recovery for current or running washer orders after app startup/session restore by using the captured Ujing `home/order/lastRunning` and `home/order/running` endpoints.
- Guard `control/start` and `control/stop` so they only run from valid order states, preserving the user decision that payment success must not unconditionally auto-start the machine.

## Capabilities

### New Capabilities
- `runtime-order-continuity`: Keeps legacy hot-water entry points reachable and makes Ujing washer order state truthful across detail screens, payment returns, manual controls, and app restarts.

### Modified Capabilities

## Impact

- Affected Android manifest entries: `app/src/main/AndroidManifest.xml`.
- Affected legacy/runtime code: `LegacyHotwaterActivity.java`, `UjingApi.java`, `UjingRuntimeAdapter.java`, and `runtime/ShuiRuntime.kt`.
- Affected Compose UI: `ui/ShuiScreens.kt` order detail and related washer order actions.
- Affected documentation/tests: update service-interface notes if endpoint behavior is clarified, then validate `assembleDebug` plus emulator/manual flows for Alipay cancel/fail/success, app restart recovery, manual start, early stop, and legacy hot-water launch.
