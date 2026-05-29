## 1. Review Gates And Runtime Setup

- [x] 1.1 Confirm with the user how first-time Zhuli hot-water login should work: new Compose password input or require one legacy login first.
- [x] 1.2 Confirm with the user how washer QR should be entered first: manual paste, camera scan, or both.
- [x] 1.3 Confirm with the user how device add/edit/delete should behave in this change: local UI-only, disabled, or backed by captured endpoints.
- [x] 1.4 Confirm with the user which payment channel presentation to use first: service-provided list, fixed Alipay default, or debug selector.
- [x] 1.5 Confirm with the user whether order history should initially merge hot water and washer data or show verified hot-water history plus current washer order only.
- [x] 1.6 Add runtime state/action classes or ViewModels that are instantiated only from runtime app entry points.
- [x] 1.7 Add fake state/action providers for Compose previews and verify previews do not reference real services.

## 2. Service Adapters

- [x] 2.1 Wrap verified hot-water start/stop/history behavior behind UI-friendly runtime methods without changing endpoint signing, BLE UUIDs, or SharedPreferences keys.
- [x] 2.2 Wrap Ujing captcha/login/session behavior behind UI-friendly runtime methods.
- [x] 2.3 Wrap Ujing washer scan/program/order/detail/cancel behavior behind UI-friendly runtime methods.
- [x] 2.4 Wrap payment method/argument/launch behavior so H5, Alipay, and WeChat launch results can update UI state and logs.
- [x] 2.5 Preserve existing legacy Activity, widget, foreground service, and Ujing test Activity behavior while adapters are added.

## 3. Compose Runtime Binding

- [x] 3.1 Bind "开热水" to runtime hot-water start state with login/session, device ID, BLE permission, loading, success, and failure handling.
- [x] 3.2 Bind "关热水" to runtime hot-water stop state and block the action when `last_isn` is missing.
- [x] 3.3 Replace runtime order/history rows with verified hot-water history and/or current washer order state according to the confirmed history decision.
- [x] 3.4 Bind account login UI to Ujing captcha/login state and cached session display.
- [x] 3.5 Bind washer scan/add-device UI to the confirmed QR input path and documented washer scan/program flow.
- [x] 3.6 Bind washer program selection and "创建订单" to validated order creation and order-detail refresh.
- [x] 3.7 Bind payment controls to payment methods/arguments, payment launch, callback/log state, and post-payment order refresh.
- [x] 3.7a Capture and implement the verified Ujing washer post-payment confirm/start-machine step before treating a paid washer order as started.
- [x] 3.8 Bind cancellation controls to current washer order cancellation and visible state refresh.
- [x] 3.9 Keep unsupported Ujing drinking-water actions disabled or routed to a "not captured yet" state.

## 4. Permissions, Errors, And Logging

- [x] 4.1 Add UI-visible handling for missing BLE, nearby-device, location, Bluetooth-enabled, and scanner/camera permissions as applicable.
- [x] 4.2 Add duplicate-click and conflicting-action guards for hot-water start/stop, washer order creation, payment, and cancellation.
- [x] 4.3 Surface service failures with user-readable messages and write debugging details to the existing local log mechanism.
- [x] 4.4 Clear or refresh sessions on documented sign/session errors such as hot-water `api_sign_error`.

## 5. Verification And Reporting

- [x] 5.1 Run `gradlew.bat assembleDebug` and record any build issue in `P_PLAN/bug.md`.
- [x] 5.2 Manually verify Compose previews/static states remain fake-only.
- [x] 5.3 Manually verify hot-water start/stop gating paths, including missing login, missing permission, and missing `last_isn`.
- [ ] 5.4 Manually verify Ujing captcha/login, washer scan/program, order creation/detail, payment launch failure/success states where available, and cancellation.
- [ ] 5.5 Manually verify existing widget/foreground-service and legacy/test Activity entry points still work or document any regression before continuing.
- [ ] 5.6 Update this task list as items are completed and write the matching `P_PLAN/part<n>.md` implementation report for the completed functional part.
