## 1. Legacy Entry Compatibility

- [x] 1.1 Register `LegacyHotwaterActivity` in `app/src/main/AndroidManifest.xml` as a non-launcher activity while keeping `MainActivity` as the only launcher.
- [x] 1.2 Verify legacy hot-water entry can be started through adb or an internal route without breaking widget/service dependencies.

## 2. Ujing Order Recovery API

- [x] 2.1 Add `UjingApi` methods for `home/order/lastRunning` and `home/order/running` with defensive parsing and raw response logging on unknown shapes.
- [x] 2.2 Add `UjingRuntimeAdapter` recovery methods that hydrate `currentOrder` and return `WasherOrderDetail` when an active washer order exists.
- [x] 2.3 Update `ShuiRuntimeController.initialState()` to restore cached Ujing session plus recovered current washer order without inventing fake state.

## 3. Payment And Control State

- [x] 3.1 Update Alipay handling so only `resultStatus=9000` is reported as payment success, while cancel/fail/pending/unknown results keep truthful UI messages.
- [x] 3.2 Refresh server order detail after payment return when possible and surface both SDK result and server order status.
- [x] 3.3 Add runtime status guards before `control/start` so unpaid, running, completed, cancelled, or missing orders cannot trigger start.
- [x] 3.4 Add runtime status guards before `control/stop` so only starting/running orders can trigger early stop.
- [x] 3.5 Preserve the rule that payment success does not automatically call `control/start` unless a future explicit auto-start option is enabled.

## 4. Runtime Order Detail UI

- [x] 4.1 Replace hard-coded `OrderDetailScreen` values with `currentWasherOrder` and related runtime action state.
- [x] 4.2 Add an empty/guidance state for order detail when no current washer order exists.
- [x] 4.3 Render payment, manual start, early stop, cancel, refresh, and status fields according to the real order status.
- [x] 4.4 Ensure order detail navigation from order-related UI uses the runtime order detail and does not show sample data.

## 5. Verification

- [x] 5.1 Run `.\gradlew.bat assembleDebug` and fix any compile errors.
- [x] 5.2 Validate emulator/manual flows for Alipay success, cancel, failure or pending return messaging.
- [x] 5.3 Validate app restart restores an active washer order when Ujing reports one and stays empty when none exists.
- [x] 5.4 Validate manual start and early stop work only in valid states.
- [x] 5.5 Validate `LegacyHotwaterActivity`, hot-water widget, and foreground service paths still compile and remain reachable.
