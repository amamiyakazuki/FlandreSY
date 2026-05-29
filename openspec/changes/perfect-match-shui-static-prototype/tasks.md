## 1. Resource and Baseline Audit

- [x] 1.1 Compare `refer` screenshots against current Compose implementation and list visible mismatches by page.
- [x] 1.2 Verify required image assets exist in `app/src/main/res/drawable` and copy/rename missing local assets from `image` if needed.
- [x] 1.3 Verify `未来圆SC Regular.ttf` is available as an Android font resource and used by `ShuiTheme`.

## 2. Shared Visual System

- [x] 2.1 Tune `ShuiTheme` colors, typography, background, and remove app-drawn fake status bar visuals.
- [x] 2.2 Tune `AdaptivePhoneContainer`, `TopHeader`, and header wave for 430dp-centered phone layout.
- [x] 2.3 Tune `BottomNavBar`/`WavyBottomBar` active states, icons, height, wave, and fixed bottom behavior.
- [x] 2.4 Tune shared cards, pills, buttons, option cards, list rows, decorative images, dialogs, and popup components.

## 3. Page Restoration

- [x] 3.1 Restore the home page against `shui_main.png`, including header character, ongoing cards, hot water card, scan card, washer card, and selected “功能” tab.
- [x] 3.2 Restore the washer order page against `shui_xiyi.png`, including washer info, option sections, switch card, and bottom price bar.
- [x] 3.3 Restore the profile page against `shui_wode.png`, including profile character, account cards, more options, bottom decoration, and selected “我的” tab.
- [x] 3.4 Restore the order history and detail pages against `shui_dingdan.png`, including category chips, list rows, detail card, bottom character, and selected “订单” tab.
- [x] 3.5 Restore the device list, device action popup, add washer dialog, and empty device page against `shui_dingdan.png`, including selected “设备” tab.

## 4. Navigation and Static Behavior

- [x] 4.1 Keep bottom tab switching for home, orders, devices, and profile.
- [x] 4.2 Provide simple static entrances for washer order, order detail, add washer dialog, device action popup, and empty device page.
- [x] 4.3 Ensure controls remain static and do not call real login, scan, payment, order, hot water, washing, BLE, or widget logic.

## 5. Verification and Reporting

- [x] 5.1 Run `gradlew.bat assembleDebug` and fix compile/resource errors within the approved scope.
- [x] 5.2 Inspect Compose previews or generated screenshots where available for key pages and record remaining visual gaps.
- [x] 5.3 Update OpenSpec task checkboxes, `P_PLAN/PLAN.md`, `P_PLAN/bug.md` if issues occur, and create a new `P_PLAN/part11.md` completion report.
