## 1. Project Setup

- [x] 1.1 Add Kotlin Android and Compose build configuration to the app module.
- [x] 1.2 Add Compose Material 3, Compose tooling, and any required AndroidX dependencies.
- [x] 1.3 Convert or replace the main app entry point so `MainActivity` can host Compose content.
- [x] 1.4 Keep existing real service/API code available for later integration, but do not wire it into this static prototype.

## 2. Resource Preparation

- [x] 2.1 Copy provided image assets from `C:\Users\kazuki\Pictures\shui` into Android drawable resources with lowercase ASCII names.
- [x] 2.2 Copy `未来圆SC Regular.ttf` into `res/font` with a valid ASCII resource name.
- [x] 2.3 Define the Compose font family and use it as the default prototype font.
- [x] 2.4 Verify all imported resources compile and render without distortion.

## 3. Theme and Layout Foundation

- [x] 3.1 Implement `ShuiTheme` with the pink/red palette, text colors, card colors, and rounded visual defaults.
- [x] 3.2 Implement `AdaptivePhoneContainer` / phone frame behavior with about 430dp maximum content width and centered large-screen layout.
- [x] 3.3 Implement fake system status bar with static 9:41 time, signal, Wi-Fi, and battery styling.
- [x] 3.4 Implement shared gradient header and wave helpers for top headers.
- [x] 3.5 Implement fixed custom bottom navigation with wave/gradient styling and safe bottom content padding.

## 4. Shared Components

- [x] 4.1 Implement `SectionCard`, `SectionTitle`, `StatusPill`, `PrimaryGradientButton`, and `OptionCard`.
- [x] 4.2 Implement `DecorativeImage` for safe asset sizing, alignment, and non-distorted rendering.
- [x] 4.3 Implement `OrderListItem` for history rows.
- [x] 4.4 Implement `DeviceListItem` for washer device rows.
- [x] 4.5 Implement `AccountCard` and `MoreOptionsCard`.
- [x] 4.6 Implement `WasherInfoCard`.
- [x] 4.7 Implement `AddWasherDialog` and `DeviceActionPopup`.

## 5. Page Implementation

- [x] 5.1 Implement the 首页 / 功能 page matching `shui_main.png`.
- [x] 5.2 Implement the 洗衣下单 page matching `shui_xiyi.png`.
- [x] 5.3 Implement the 我的 page matching `shui_wode.png`.
- [x] 5.4 Implement the 历史订单 page matching the left-top area of `shui_dingdan.png`.
- [x] 5.5 Implement the 订单详情 page matching the right-top area of `shui_dingdan.png`.
- [x] 5.6 Implement the 选择洗衣机 page matching the left-bottom area of `shui_dingdan.png`.
- [x] 5.7 Implement the 选择洗衣机 action popup matching the lower-middle area of `shui_dingdan.png`.
- [x] 5.8 Implement the 添加洗衣机 dialog matching the right-middle area of `shui_dingdan.png`.
- [x] 5.9 Implement the 空设备 page matching the right-bottom area of `shui_dingdan.png`.

## 6. Static Navigation

- [x] 6.1 Implement `ShuiApp` state for bottom-tab switching between 功能、订单、设备、我的.
- [x] 6.2 Add simple static routes or buttons to open 洗衣下单、订单详情、添加洗衣机弹窗、设备菜单弹窗、空设备页.
- [x] 6.3 Ensure selected tab state matches each page.
- [x] 6.4 Ensure controls are static and do not call real login, scan, hot water, washing, payment, or order APIs.

## 7. Preview and Verification

- [x] 7.1 Add Compose previews for core pages or major reusable components where practical.
- [x] 7.2 Run `assembleDebug` and fix compile/resource issues.
- [x] 7.3 Capture or inspect phone-width screenshots for home, washing order, profile, order, and device pages.
- [x] 7.4 Tune spacing, colors, image sizes, rounded corners, and text overflow against the reference screenshots.
- [x] 7.5 Verify content does not overflow or overlap on narrow phone width and remains centered on larger width.
