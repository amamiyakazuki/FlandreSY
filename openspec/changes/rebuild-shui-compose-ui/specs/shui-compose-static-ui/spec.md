## ADDED Requirements

### Requirement: Compose static prototype
The app SHALL provide a Kotlin + Jetpack Compose static UI prototype for the 芙兰水衣 redesign.

#### Scenario: App launches to home prototype
- **WHEN** the user opens the app
- **THEN** the app displays the static 首页 / 功能 page implemented in Compose

#### Scenario: Prototype avoids real service calls
- **WHEN** the user interacts with prototype controls such as login, scan, create order, or payment-looking buttons
- **THEN** the app MUST NOT call real hot water, U净, payment, scan, or order APIs as part of this visual prototype change

### Requirement: Reference visual fidelity
The UI SHALL closely reproduce the provided reference screenshots and preserve the 芙兰水衣 visual style.

#### Scenario: Pink themed visual language
- **WHEN** any prototype page is displayed
- **THEN** the page uses the pink/red visual theme, pale pink-white background, rounded pink-bordered cards, decorative assets, and custom font treatment matching the references

#### Scenario: Avoid generic Material appearance
- **WHEN** buttons, cards, headers, and bottom navigation are rendered
- **THEN** they MUST be custom-styled to match the reference screenshots rather than appearing as default Material components

### Requirement: Local assets and font
The app SHALL use the supplied local image assets and the supplied local font file.

#### Scenario: Image assets are used
- **WHEN** pages require characters, decorations, washers, scan art, empty states, or bottom illustrations
- **THEN** the app uses the corresponding local assets from the provided shui asset set after importing them into Android resources

#### Scenario: Custom font is used
- **WHEN** text is rendered in the prototype
- **THEN** the app uses the imported 未来圆SC Regular font family, with simulated bold styling for headings, card titles, and button text

### Requirement: Adaptive phone container
The prototype SHALL adapt to phone widths while keeping content phone-sized on larger displays.

#### Scenario: Small phone width
- **WHEN** the app runs on a narrow phone screen
- **THEN** the content fits the available width without horizontal overflow

#### Scenario: Large screen width
- **WHEN** the app runs on a large phone, foldable, tablet, or desktop-like emulator
- **THEN** the content remains constrained to about 430dp wide and centered instead of becoming a tablet layout

### Requirement: Static system chrome reproduction
The prototype SHALL visually reproduce the screenshot status/header area and reduce native system chrome interference.

#### Scenario: Fake status bar
- **WHEN** a page is displayed
- **THEN** the top area includes a static fake status bar with time 9:41 and matching signal/battery styling

#### Scenario: Custom header shape
- **WHEN** a page with a top header is displayed
- **THEN** the header uses a red-pink gradient and wave-like bottom treatment similar to the reference screenshots

### Requirement: Bottom tab navigation
The app SHALL provide a fixed bottom tab bar for the primary prototype sections.

#### Scenario: Tab bar sections
- **WHEN** the bottom navigation is visible
- **THEN** it shows 功能、订单、设备、我的 tabs with the correct selected state for the current page

#### Scenario: Tab bar does not cover content
- **WHEN** page content scrolls behind the fixed bottom navigation area
- **THEN** the content includes enough bottom padding so controls and illustrations are not obscured

### Requirement: Required pages
The prototype SHALL include static versions of all requested pages and modal states.

#### Scenario: Home page
- **WHEN** the 功能 tab is selected
- **THEN** the app displays the home page with the gradient header, 芙兰水衣 title, home character, ongoing card, three status cards, hot water control card, scan card, washing device card, and selected 功能 tab

#### Scenario: Washing order page
- **WHEN** the washing order page is opened
- **THEN** the app displays static washer information, package options, temperature options, detergent options, disinfectant options, auto-create toggle, and bottom price bar matching the reference

#### Scenario: Profile page
- **WHEN** the 我的 tab is selected
- **THEN** the app displays the profile page with account cards for 住理生活 and U净, more options, profile illustrations, and selected 我的 tab

#### Scenario: Order pages
- **WHEN** the 订单 tab or order detail entry is opened
- **THEN** the app displays the historical order list page and order detail page with static data matching the requested content

#### Scenario: Device pages and dialogs
- **WHEN** the 设备 tab or device actions are opened
- **THEN** the app displays the washing machine list page, device action popup, add washing machine dialog, and empty device state matching the requested content

### Requirement: Componentized Compose implementation
The UI SHALL be split into reusable Compose components suitable for future integration.

#### Scenario: Required components exist
- **WHEN** implementation is complete
- **THEN** the code includes reusable Compose components for ShuiApp, ShuiTheme, AdaptivePhoneContainer, TopHeader, FakeStatusBar, BottomNavBar, SectionCard, SectionTitle, StatusPill, PrimaryGradientButton, OptionCard, OrderListItem, DeviceListItem, AccountCard, MoreOptionsCard, WasherInfoCard, AddWasherDialog, DeviceActionPopup, DecorativeImage, and wave/header helpers

#### Scenario: Components accept static state
- **WHEN** components render page sections
- **THEN** they accept data/state parameters rather than hard-coding all content inside a single monolithic function

### Requirement: Static navigation and previewability
The prototype SHALL be easy to preview and navigate without real backend dependencies.

#### Scenario: Basic page switching
- **WHEN** the user taps bottom tabs or static page entry buttons
- **THEN** the app switches between prototype screens using local Compose state or another lightweight static navigation method

#### Scenario: Compose previews
- **WHEN** developers open the project in Android Studio
- **THEN** core screens or major components have Compose Preview entry points where practical
