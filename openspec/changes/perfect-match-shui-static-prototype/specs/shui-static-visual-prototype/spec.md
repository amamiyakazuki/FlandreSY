## ADDED Requirements

### Requirement: Static Compose app entry
The app SHALL provide a Kotlin + Jetpack Compose static prototype entry that launches to the home page and does not require backend, login, scan, payment, or order services.

#### Scenario: App starts on home
- **WHEN** the user launches the app
- **THEN** the system displays the “芙兰水衣” home screen as the first screen

#### Scenario: Prototype remains static
- **WHEN** the user taps visual controls such as login, scan, pay, hot water, or service-check buttons
- **THEN** the system MUST NOT call real backend, scan, login, payment, order, hot water, or washing APIs

### Requirement: Local visual assets and font
The prototype SHALL use the provided local image assets and the provided `未来圆SC Regular.ttf` font for the restored UI.

#### Scenario: Image assets are rendered locally
- **WHEN** a screen includes a character, washer, scan, empty, wing, heart, star, bat, or bottom decoration
- **THEN** the system renders the matching local drawable resource without generating replacement character art

#### Scenario: Font is applied
- **WHEN** Chinese page text, card titles, and button labels are displayed
- **THEN** the system uses the local rounded font family or the closest resource name derived from it

### Requirement: Phone-sized adaptive layout
The prototype SHALL constrain content to a phone-sized layout with maximum width near 430dp and center it on larger screens.

#### Scenario: Large screen centering
- **WHEN** the app is displayed on a screen wider than phone width
- **THEN** the phone content remains approximately 430dp wide and centered instead of becoming a tablet two-column layout

#### Scenario: Small screen fitting
- **WHEN** the app is displayed on a narrow phone screen
- **THEN** text, cards, buttons, bottom navigation, and images remain within their containers without incoherent overlap

### Requirement: Restored shared visual system
The prototype SHALL reproduce the screenshot visual system with shallow pink background, red-pink gradient headers, rounded cards, pale pink borders, wave shapes, and red-pink gradient bottom navigation, while avoiding any app-drawn fake phone status bar.

#### Scenario: Header without fake status bar
- **WHEN** any primary or secondary page is displayed
- **THEN** the top area displays the red-pink gradient header beneath the real system status bar and does not app-render fake 9:41, signal, Wi-Fi, or battery indicators

#### Scenario: Bottom navigation
- **WHEN** a tabbed page is displayed
- **THEN** the bottom navigation remains fixed, uses the red-pink visual style with wave treatment, and highlights the active tab

#### Scenario: Cards and background
- **WHEN** cards and sections are displayed
- **THEN** they use shallow pink/white backgrounds, rounded corners, thin pale-pink borders, and spacing close to the reference screenshots

### Requirement: Home page restoration
The prototype SHALL restore the home page corresponding to `shui_main.png`.

#### Scenario: Home content
- **WHEN** the home tab is selected
- **THEN** the page displays the “芙兰水衣” header, settings action, `home_top_character.png`, ongoing status card, hot water control card, scan card, washing device card, and selected “功能” bottom tab

### Requirement: Washer order page restoration
The prototype SHALL restore the washer order page corresponding to `shui_xiyi.png`.

#### Scenario: Washer order content
- **WHEN** the washer order page is opened
- **THEN** the page displays the “洗衣下单” header, washer info card, package options, temperature options, detergent options, disinfectant options, auto-create switch card, and bottom price bar with “预计价格 ¥6.00” and “创建订单”

### Requirement: Profile page restoration
The prototype SHALL restore the profile page corresponding to `shui_wode.png`.

#### Scenario: Profile content
- **WHEN** the profile tab is selected
- **THEN** the page displays the “我的” header, settings action, `profile_top_character.png`, two account cards, more options card, `shui_wode_bottom.png`, and selected “我的” bottom tab

### Requirement: Order pages restoration
The prototype SHALL restore the order history and order detail screens from `shui_dingdan.png`.

#### Scenario: History order content
- **WHEN** the order tab is selected
- **THEN** the page displays the “历史订单” header, category buttons, four static hot water order rows, `order_bottom_character.png`, and selected “订单” bottom tab

#### Scenario: Order detail content
- **WHEN** an order detail entry is opened
- **THEN** the page displays the “订单详情” header, order number, device number, status, amount, time, `order_bottom_character.png`, and selected “订单” bottom tab

### Requirement: Device pages and popups restoration
The prototype SHALL restore the washer selection list, device action popup, add washer dialog, and empty device page from `shui_dingdan.png`.

#### Scenario: Device list content
- **WHEN** the device tab is selected
- **THEN** the page displays the “选择洗衣机” header, plus action, refresh bar, four static washer rows using `washer_machine.png`, `order_bottom_character.png`, and selected “设备” bottom tab

#### Scenario: Device action popup
- **WHEN** the device menu popup is shown
- **THEN** the page background is dimmed and a small rounded pale-pink menu displays “编辑名称” and “删除设备”

#### Scenario: Add washer dialog
- **WHEN** the add washer dialog is shown
- **THEN** the page background is dimmed and a centered rounded dialog displays the title, description, “开始扫码”, “取消”, and close action

#### Scenario: Empty device content
- **WHEN** the empty device page is opened
- **THEN** the page displays the “选择洗衣机” header, refresh bar, `empty_box.png`, “暂无设备”, “点击右上角 + 添加洗衣机”, and selected “设备” bottom tab

### Requirement: Componentized implementation
The prototype SHALL keep the UI componentized with named Compose components for shared layout, navigation, cards, options, list items, dialogs, popups, decorations, and waves.

#### Scenario: Required components exist
- **WHEN** the implementation is reviewed
- **THEN** it includes components named `ShuiApp`, `ShuiTheme`, `AdaptivePhoneContainer` or `PhoneFrame`, `TopHeader`, `BottomNavBar`, `SectionCard`, `SectionTitle`, `StatusPill`, `PrimaryGradientButton`, `OptionCard`, `OrderListItem`, `DeviceListItem`, `AccountCard`, `MoreOptionsCard`, `WasherInfoCard`, `AddWasherDialog`, `DeviceActionPopup`, `DecorativeImage`, and `WavyBottomBar` or `CanvasWave`

### Requirement: Preview and build readiness
The prototype SHALL be buildable and previewable in Android Studio.

#### Scenario: Debug build
- **WHEN** the Android debug build is run
- **THEN** the build completes without Kotlin or resource compilation errors

#### Scenario: Compose previews
- **WHEN** Android Studio Compose Preview loads the provided preview functions
- **THEN** the main restored pages can be inspected without requiring real services
