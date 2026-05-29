## Why

The project now has a static Compose UI, but the real hot water and Ujing flows still live in older experimental code and conversation history. A durable interface document is needed before further UI work so future integration can be implemented without relying on memory.

## What Changes

- Add a detailed service interface document describing when each real API or BLE step is called, what state triggers it, what request type it uses, and what data the UI should expect.
- Cover the currently known service domains:
  - Zhuli Life hot water account, device, BLE consume, end consume, and history flow.
  - Ujing phone-login, washer scan, washer program, order, payment, cancel, and payment callback flow.
  - Ujing drinking-water flow as a known but incomplete area, with explicit unknowns to re-capture later.
- Document integration boundaries between the static Compose UI and future ViewModel/service layers.
- Do not change runtime behavior or wire real calls into the Compose prototype in this change.

## Capabilities

### New Capabilities

- `service-interface-documentation`: Documents the real service interfaces, lifecycle triggers, request/response expectations, state ownership, and known unknowns needed for later integration.

### Modified Capabilities

None.

## Impact

- Adds OpenSpec artifacts for the documentation change.
- Adds project documentation under `docs/`.
- Does not modify API clients, BLE code, payment code, or Compose runtime behavior.
