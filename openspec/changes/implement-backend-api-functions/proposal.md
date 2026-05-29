## Why

The current Compose UI is a static prototype: buttons, tabs, device dialogs, order pages, and account cards express user intent but do not execute the real hot water, washer, order, or payment flows. The project now has documented service boundaries in `docs/service-interfaces.md`, so the next change should connect the finished front-end interactions to the verified backend/API/BLE/payment implementations without leaking real services into previews.

## What Changes

- Add a runtime action/state layer between Compose UI and existing Java service/API classes.
- Connect hot water buttons to validated start/stop flows with login/session checks, BLE permission checks, duplicate-click protection, and user-visible errors.
- Connect Ujing washer flows to captcha login, washer QR scan, program loading, order creation, payment argument retrieval, payment launch, order refresh, and cancellation.
- Replace static order/device/account data in runtime screens with state sourced from repositories or existing services while keeping Compose previews fake-only.
- Preserve documented boundaries for Ujing drinking water: do not implement drinking-water scan/order/payment until endpoints are captured and reviewed.
- Add verification tasks for build, state transitions, failure handling, and regression of the existing widget/legacy flows.

## Capabilities

### New Capabilities

- `compose-runtime-actions`: Runtime ViewModel/action contracts that bind existing Compose UI events to service calls, expose loading/success/failure state, and keep previews isolated from real services.
- `hotwater-control`: Real hot water login, start, stop, and history behavior reachable from the new UI using the documented Zhuli API, BLE lifecycle, and SharedPreferences keys.
- `ujing-washer-ordering`: Real Ujing washer login, scan, program selection, order, payment, refresh, and cancellation behavior reachable from the new UI using the documented Ujing API and payment SDK boundaries.

### Modified Capabilities

- None.

## Impact

- Affected UI/runtime code: `MainActivity.kt`, `app/src/main/java/com/kazuki/zhulihotwater/ui/`, and new ViewModel/repository/action classes as needed.
- Affected existing services: `LegacyHotwaterActivity`, `HotwaterActionRunner`, `HistoryActivity`, `UjingApi`, `UjingWasherTestActivity`, `WXPayEntryActivity`, `HotwaterActionService`, and `HotwaterWidgetProvider`.
- Affected Android systems: BLE permissions, nearby-device/location permission prompts, system Intent payment/H5 launch, Alipay SDK, WeChat SDK callback, foreground service/widget hot water entry points.
- Affected storage: SharedPreferences namespace `zhuli_hotwater` and documented keys for Zhuli and Ujing sessions/orders.
- Main risks: real payment may be constrained by merchant package/signature binding; hot water stop depends on `last_isn`; drinking-water APIs are not known; previews must never call real services.
