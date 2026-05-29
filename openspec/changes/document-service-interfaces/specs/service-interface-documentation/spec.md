## ADDED Requirements

### Requirement: Canonical service interface document
The project SHALL include a canonical Markdown document describing real service interfaces needed for future integration.

#### Scenario: Documentation exists
- **WHEN** a developer needs to reconnect real functionality to the Compose UI
- **THEN** the developer can read a project-local document under `docs/` that explains the service flows and endpoints

### Requirement: Lifecycle-based API flow documentation
The service document SHALL describe when each API or BLE step is called and what app state triggers it.

#### Scenario: Hot water integration
- **WHEN** the future UI implements hot water start or stop
- **THEN** the document explains the required login/session, device lookup, BLE handshake, order creation, BLE write, response confirmation, and stop flow order

#### Scenario: Ujing washer integration
- **WHEN** the future UI implements washer scan, order creation, payment, or cancellation
- **THEN** the document explains the required Ujing login/session, QR scan, program lookup, order creation, payment argument, payment callback, and cancel flow order

### Requirement: Endpoint detail documentation
The service document SHALL classify each known endpoint by method/type, service domain, required state, parameters, response fields, and side effects.

#### Scenario: Endpoint lookup
- **WHEN** a developer searches for an endpoint such as `orders/create` or `consume/create_order`
- **THEN** the document identifies the HTTP method, base URL, required headers/signature/session, key parameters, important response fields, and calling context

### Requirement: Unknown and risky areas are explicit
The service document SHALL distinguish verified implementation details from incomplete or risky areas.

#### Scenario: Drinking-water flow
- **WHEN** a developer reads the drinking-water section
- **THEN** the document states which parts are known from QR/payment behavior and which parts still require capture before implementation

#### Scenario: Payment limitations
- **WHEN** a developer reads the payment section
- **THEN** the document states that Alipay standard payment has been tested and that WeChat payment may be blocked by app package/signature or merchant configuration

### Requirement: Static UI remains disconnected
The documentation change SHALL NOT connect the static Compose UI to real network, BLE, login, scan, payment, or order calls.

#### Scenario: Running the app after documentation change
- **WHEN** the app is built and launched after this change
- **THEN** the Compose prototype remains visually static and does not call real services from its UI controls
