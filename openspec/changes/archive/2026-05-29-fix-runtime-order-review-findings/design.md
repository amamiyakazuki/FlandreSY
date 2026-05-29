## Context

The app currently has a Compose shell for the Shui UI plus Java/Kotlin runtime adapters for Zhuli hot water and Ujing washer flows. The washer flow can create, pay, manually start, stop, and cancel an order, but review found gaps where UI state is still static or too optimistic. The legacy hot-water activity is still a dependency for API/BLE code and older entry paths, so removing its activity declaration is a compatibility regression.

The captured Ujing workflow shows separate lifecycle states for reserved/unpaid, paid, starting, running, and completed orders. A paid order must not automatically call `control/start` unless a user-selected auto-start option is explicitly implemented and enabled. The current implementation should therefore treat payment, start, and stop as distinct runtime actions.

## Goals / Non-Goals

**Goals:**
- Keep the legacy Zhuli hot-water screen launchable while the Compose app remains the primary launcher.
- Make the order detail page consume the active washer order from runtime state instead of static sample content.
- Interpret Alipay SDK return status before showing success messaging or updating UI state.
- Restore an active washer order after app restart/session restore using Ujing running-order endpoints.
- Validate manual start/stop calls against order status before sending control requests.

**Non-Goals:**
- Redesign the visual Shui UI or change the 1:1 restoration work.
- Add a new backend, real drinking-water integration, or iOS/KMP support.
- Automatically start the washer after payment unless the explicit auto-start option is later wired to that behavior.
- Remove or rewrite the legacy Java hot-water implementation.

## Decisions

1. Restore `LegacyHotwaterActivity` as a non-launcher activity.

   Rationale: The codebase still uses `LegacyHotwaterActivity` for API types, logging, BLE session classes, and historical/debug entry paths. Keeping it registered is the smallest compatibility fix. The alternative, formal deprecation, would require deleting or replacing dependent routes and is outside this review-fix change.

2. Treat `currentWasherOrder` as the single source of truth for order detail UI.

   Rationale: The detail page should show the same order the runtime actions operate on. If no current order exists, it should show an empty or guidance state rather than fake order data. The alternative, passing a separate static order id through navigation, would still need runtime lookup and risks divergence from the action buttons.

3. Add Ujing API methods for running-order recovery in the adapter layer.

   Rationale: `UjingApi` should own endpoint paths and JSON parsing, while `UjingRuntimeAdapter` owns current-order selection/cache. `ShuiRuntimeController.initialState()` can then restore account plus active order without embedding HTTP details in Compose-facing state.

4. Branch on Alipay `resultStatus` before success UI state.

   Rationale: `9000` is the only clear success result. Cancel, failure, pending, and unknown statuses must keep the order detail truthful by refreshing when useful but not claiming payment success. The UI message should mention the SDK result and the refreshed server order status.

5. Guard `control/start` and `control/stop` by status in runtime.

   Rationale: The UI hides invalid buttons, but runtime-level checks prevent future entry points from starting unpaid/completed orders or stopping non-running orders. Start should be allowed only for paid/startable states, and stop only for starting/running states verified from refreshed order detail when possible.

## Risks / Trade-offs

- Running-order endpoints may return different JSON shapes than captured flows -> parse defensively, log raw response on unknown shape, and leave runtime state empty instead of crashing.
- Alipay may return success while server detail has not updated yet -> show SDK success with refreshed server status and keep a manual refresh path, rather than forcing paid state locally.
- Restoring `LegacyHotwaterActivity` could expose an old UI route that is visually inconsistent -> keep it non-launcher/exported false unless a specific external entry requires otherwise.
- Status codes may vary across Ujing order types -> centralize status constants and preserve raw status/statusRemark in UI for diagnostics.

## Migration Plan

1. Add the manifest activity entry for `LegacyHotwaterActivity`.
2. Add Ujing API/adapter methods for last-running/running order lookup and current-order hydration.
3. Update runtime initial state and refresh actions to populate `currentWasherOrder` from real detail.
4. Update the order detail Compose screen to render runtime order fields and action buttons only from valid state.
5. Update Alipay result handling and start/stop guards.
6. Run `assembleDebug`, then verify emulator/manual flows: legacy hot-water launch, payment cancel/fail/success, app restart recovery, manual start, and early stop.
