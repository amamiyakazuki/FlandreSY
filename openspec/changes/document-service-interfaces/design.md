## Context

The app has two parallel realities: a new static Compose UI and older working/test code for Zhuli hot water plus Ujing washing/payment. The UI will be redesigned iteratively, but later integration must know exactly which calls are safe to make, which calls require account state, which calls require BLE proximity, and which parts are still unknown.

The strongest sources of truth are current code in `LegacyHotwaterActivity`, `HotwaterActionRunner`, `UjingApi`, `UjingWasherTestActivity`, earlier `P_PLAN` notes, and the captured QR examples. The documentation must clearly separate verified behavior from inferred or incomplete behavior.

## Goals / Non-Goals

**Goals:**

- Produce a durable service interface document under `docs/` for future integration.
- Document call timing, trigger conditions, request method/type, required state, important parameters, response fields, side effects, and failure handling.
- Cover Zhuli hot water, Ujing washer, Ujing payment, Ujing drinking-water known unknowns, account/session storage, and UI integration boundaries.
- Record which real calls must never happen from static preview or design-only UI.

**Non-Goals:**

- Do not add or change API client behavior.
- Do not connect the Compose prototype to real services.
- Do not reverse engineer additional APK code or capture new flows in this change.
- Do not store user credentials or tokens in docs.

## Decisions

1. **Create one canonical Markdown document.**

   Alternatives considered: splitting by service or writing only OpenSpec specs. A single `docs/service-interfaces.md` is easier to search and safer against context loss. OpenSpec artifacts define the documentation contract, while the docs file carries the detailed operational knowledge.

2. **Use lifecycle-first structure instead of endpoint-only structure.**

   Endpoint tables are useful, but integration work usually fails because the order and state prerequisites are forgotten. The document will first describe flows such as "start hot water", "stop hot water", "create washer order", and "pay order", then list endpoint details.

3. **Mark confidence explicitly.**

   Verified code paths, captured-but-not-integrated data, and unknown areas such as Ujing drinking-water order discovery must be labeled differently. This prevents later implementation from treating guesses as contracts.

4. **Keep sensitive values out of docs.**

   Known constants already present in code may be referenced by name, but user phone numbers, passwords, tokens, order IDs, and secrets must not be copied into documentation.

## Risks / Trade-offs

- **Risk: Documentation drifts from code.** → Mitigation: link each implemented flow to the owning Java class/method and require updates when API code changes.
- **Risk: Unknown drinking-water flow is mistaken as implemented.** → Mitigation: document it as incomplete and list exactly what must be captured later.
- **Risk: Payment docs overpromise WeChat support.** → Mitigation: record that Alipay standard orderInfo works in testing, while WeChat SDK can fail because package/signature/merchant binding may reject this app.
- **Risk: Future Compose integration calls real APIs during previews.** → Mitigation: explicitly require service calls only from runtime ViewModel/actions, never Preview/static design state.
