## 1. Source Review

- [x] 1.1 Review current Zhuli hot water API and BLE flow in `LegacyHotwaterActivity` and `HotwaterActionRunner`.
- [x] 1.2 Review current Ujing washer, order, payment, and callback flow in `UjingApi`, `UjingWasherTestActivity`, and `WXPayEntryActivity`.
- [x] 1.3 Review existing project notes for captured endpoints and known limitations.

## 2. Documentation

- [x] 2.1 Create `docs/service-interfaces.md`.
- [x] 2.2 Document account/session ownership for Zhuli Life and Ujing.
- [x] 2.3 Document Zhuli hot water start, stop, history, endpoint, signature, BLE, and failure flows.
- [x] 2.4 Document Ujing washer login, scan, program, order, payment, cancel, and callback flows.
- [x] 2.5 Document Ujing drinking-water known flow and explicit unknowns that still require capture.
- [x] 2.6 Document how future Compose UI/ViewModel layers should call services without triggering real APIs in previews.

## 3. Verification

- [x] 3.1 Check the document against current code references for endpoint names and state fields.
- [x] 3.2 Run OpenSpec status and confirm the documentation change is apply-ready or complete.
