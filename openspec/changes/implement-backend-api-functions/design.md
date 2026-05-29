## Context

The app currently contains two worlds: a finished Compose static prototype in `MainActivity.kt` and `ui/`, and verified legacy/runtime service code in Java classes such as `HotwaterActionRunner`, `LegacyHotwaterActivity`, `HistoryActivity`, `UjingApi`, `UjingWasherTestActivity`, and `WXPayEntryActivity`. `docs/service-interfaces.md` documents the safe boundaries for Zhuli hot water, Ujing washer, payment, shared storage, and the still-unknown Ujing drinking-water flow.

This change will connect the Compose UI to real runtime behavior. It must preserve the static-preview contract: previews and design-only state continue to use fake data and never call network, BLE, scanner, payment, foreground service, or token-bearing code.

## Goals / Non-Goals

**Goals:**

- Introduce a runtime ViewModel/action layer that maps Compose user intent to service calls and exposes explicit UI state.
- Reuse verified Java API/BLE/payment implementations instead of rewriting signing, BLE, or payment logic from scratch.
- Add safe UI gating for login, permission, loading, duplicate-click, current order, and error states.
- Make hot water start/stop/history and Ujing washer login/scan/order/payment/cancel reachable from the new UI.
- Keep widget and legacy flows working while the new UI is integrated.

**Non-Goals:**

- Do not implement Ujing drinking-water scan/order/payment until endpoints are captured and reviewed.
- Do not change endpoint contracts, signing rules, BLE UUIDs, payment SDK bindings, or SharedPreferences key names unless required by existing code.
- Do not make Compose previews or screenshot/design states depend on real services.
- Do not guarantee successful WeChat/Alipay payment completion when merchant package/signature binding rejects this app; record and surface failures instead.

## Decisions

1. Add a runtime state/action layer for Compose.

   Rationale: Compose screens already express actions such as opening washer order, creating an order, opening order detail, adding devices, and starting hot water. A ViewModel/action layer keeps UI declarative and centralizes permission, loading, and error handling.

   Alternatives considered:

   - Call Java service classes directly from Composables. This is simpler initially but makes lifecycle, preview isolation, permission prompts, and duplicate-click protection fragile.
   - Rewrite the whole app around a new Kotlin data layer. This is cleaner long term but risks breaking verified signing/BLE/payment code.

2. Reuse existing service implementations behind small adapters.

   Rationale: The existing Java classes already encode verified API signatures, SharedPreferences keys, BLE response parsing, payment SDK calls, and callback handling. Thin adapters can expose suspend/callback-friendly operations without changing known behavior.

   Alternatives considered:

   - Move all Java code to Kotlin before integration. This adds risk and delays the user-visible goal.
   - Keep using the old test Activities as integration entry points. This avoids new adapters but cannot drive the new Compose UI state cleanly.

3. Model UI state explicitly per feature.

   Rationale: Hot water, washer, order, account, and payment flows have different loading and failure states. Explicit state prevents impossible combinations such as starting and stopping hot water concurrently or paying without an order.

   Alternatives considered:

   - Use simple global loading/error strings. This is quick but loses the state needed for disabling buttons and resuming flows.
   - Persist all state immediately. This risks storing sensitive or transient values that should remain runtime-only.

4. Keep payment launch best-effort and verify by order refresh.

   Rationale: Current implementation scope will expose only Alipay to users and show a clear message that only Alipay is supported for now. `payment/arguments` can still contain H5 links or other fields, but the user-facing path should prioritize `alipay` / `orderInfo` and refresh order detail after payment returns rather than trusting SDK return alone.

   Alternatives considered:

   - Treat SDK callback as final truth. This is unsafe because callbacks can fail, be delayed, or only indicate launch result.
   - Show a debug channel selector. This helps testing, but the current user-facing product scope only needs Alipay.
   - Display service-provided channels. This is more complete, but may expose unsupported paths before they are ready.

5. Treat the in-app device list as local shortcuts, not official account binding.

   Rationale: The finished UI needs a device list for quick selection, but the project does not have verified official add/edit/delete/bind endpoints. A local shortcut list can safely store alias, QR URL or `cd`, device type, last known state, and sort order. Opening or refreshing a washer shortcut reuses the saved QR URL with `scanWasherCode`, then loads `program/info` when the device is orderable. Drinking-water shortcuts may store `cd` values, but their runtime flow remains disabled until the drinking-water scan/order endpoints are captured.

   Alternatives considered:

   - Use official device binding endpoints. This is not safe yet because those endpoints are not documented or verified.
   - Disable all device list management. This is safe but loses the intended "scan once, reuse later" workflow.

## Risks / Trade-offs

- [Risk] Hot water stop cannot work without `last_isn` from a successful app-started session -> Mitigation: gate the stop action and show a clear message when `last_isn` is missing.
- [Risk] BLE permissions and Android version differences can block start/stop -> Mitigation: centralize permission checks and expose actionable UI errors before calling BLE.
- [Risk] Payment SDK/H5 launch can fail due to package, signature, appId, or channel limitations -> Mitigation: log raw failure details, surface user-readable status, and always refresh order detail.
- [Risk] Existing Java code may be Activity-coupled -> Mitigation: extract or wrap only the reusable action parts needed for runtime integration; keep legacy Activities available until parity is verified.
- [Risk] Static UI previews accidentally call real services -> Mitigation: require fake repositories for previews and instantiate real ViewModels only from runtime entry points.
- [Risk] Ujing drinking-water buttons or labels may imply unsupported functionality -> Mitigation: keep drinking-water actions disabled or routed to a documented "not captured yet" state until the user provides capture data and approves an implementation path.
- [Risk] Users may assume local device deletion affects the official account -> Mitigation: label and implement edit/delete as local-only operations that never call official account binding APIs.

## Migration Plan

1. Add runtime state/action classes and adapters without changing visible static UI behavior.
2. Wire one flow at a time behind the existing Compose buttons, starting with non-payment or lower-risk actions.
3. Preserve old legacy/test Activity entry points until the new UI has build and manual verification.
4. Run `gradlew.bat assembleDebug` after each implemented part and record issues in `P_PLAN/bug.md`.
5. Rollback strategy: disconnect the new runtime ViewModel from Compose and keep existing legacy/test Activities and widget flows as fallback.

## Open Questions

- Should the new UI expose a password input for first-time Zhuli hot water login, or require the user to complete login through the legacy flow once?
- Should washer QR input start as manual text/paste, camera scan, or both?
- Resolved: device add/edit/delete is local-only for this change. It manages this app's shortcut list and does not affect official Ujing/Zhuli account binding data.
- Resolved: payment UI will expose Alipay first/only for this change and tell users that only Alipay is currently supported.
- Resolved: order UI remains separated as currently designed. Hot-water history uses the verified hot-water history API, while washer UI shows only the current washer order/detail state created by this app.
