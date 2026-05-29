## ADDED Requirements

### Requirement: Ujing account login supports captcha flow

The system SHALL allow the new UI to request a Ujing captcha by mobile number and complete Ujing login by mobile number plus captcha. Successful login MUST cache the documented Ujing session fields and failures MUST expose the service message.

#### Scenario: Captcha requested

- **WHEN** the user enters a mobile number and requests a captcha
- **THEN** the system calls the documented `captcha` endpoint and reports whether the request was accepted

#### Scenario: Login succeeds

- **WHEN** the user submits mobile number and captcha accepted by Ujing
- **THEN** the system stores `mobile`, `token`, `userId`, and `serviceSubjectId` in the documented session cache and updates account state to logged in

### Requirement: Washer scan loads device and program state

The system SHALL scan a washer QR value through the documented Ujing washer scan endpoint and load washer program information when order creation is enabled. If `createOrderEnabled=false`, the system MUST show the returned reason and MUST NOT continue to order creation.

#### Scenario: Scan and program load succeeds

- **WHEN** a logged-in user provides a valid washer QR code
- **THEN** the system scans the washer, loads program information, and exposes device, store, wash model, and temperature choices to the UI

#### Scenario: Device cannot create order

- **WHEN** the scan result says `createOrderEnabled=false`
- **THEN** the system displays the returned reason and blocks order creation

### Requirement: Washer order creation uses selected program data

The system SHALL create washer orders only after login, scan, program info, `storeId`, selected wash model, and selected temperature are available. The system MUST retrieve and display order detail after creating an order.

#### Scenario: Order creation succeeds

- **WHEN** the user taps "创建订单" with valid program and selection state
- **THEN** the system calls the documented `orders/create` endpoint, stores the current order ID, fetches order detail, and displays current order status and price

#### Scenario: Order creation lacks program state

- **WHEN** the user taps "创建订单" before scan/program state is available
- **THEN** the system blocks the action and asks the user to scan or select a washer first

### Requirement: Washer payment launch uses Alipay first and is followed by refresh

The system SHALL expose Alipay as the supported user-facing washer payment path for this change and SHALL tell users that only Alipay is currently supported. The system MUST retrieve payment arguments for the current washer order, launch Alipay when `orderInfo` is available, refresh order detail after payment returns, and surface launch failures.

#### Scenario: Alipay orderInfo is returned

- **WHEN** payment arguments include Alipay `orderInfo`
- **THEN** the system launches the Alipay SDK flow and refreshes order detail after the SDK returns

#### Scenario: Unsupported payment channel is visible in service data

- **WHEN** service data includes non-Alipay payment fields or channels
- **THEN** the user-facing UI does not offer those channels and explains that only Alipay is currently supported

#### Scenario: Alipay launch fails

- **WHEN** Alipay launch fails or returns an error
- **THEN** the system shows the failure and keeps the order in a refreshable payment state

### Requirement: Washer order cancellation is available for current unpaid orders

The system SHALL allow cancellation of the current washer order when an order ID exists and the order state allows cancellation.

#### Scenario: Cancel succeeds

- **WHEN** the user cancels a current washer order
- **THEN** the system calls the documented cancel endpoint, clears or marks the current order state, and refreshes visible order detail

#### Scenario: Cancel has no order

- **WHEN** the user attempts cancellation without a current order ID
- **THEN** the system blocks the action and reports that there is no active washer order to cancel
