## Context

The current Android project is a traditional Java/View implementation with working experimental hot water and U净 test logic. The requested change is a visual prototype rewrite, not a feature integration pass: the app should become a Kotlin + Jetpack Compose static interface that closely reproduces the provided "芙兰水衣" reference screenshots.

Reference screenshots live under `C:\Users\kazuki\Pictures\杂`, and production UI assets plus the custom font live under `C:\Users\kazuki\Pictures\shui`. The prototype must use these local assets rather than generated replacements.

## Goals / Non-Goals

**Goals:**

- Build a static Compose app shell that launches to the 首页 / 功能 page.
- Reproduce the visual language of the screenshots: pink/red gradients, soft pink background, rounded cards, thin pink borders, wave headers/tab bars, decorative pixel/Q-style assets, custom font, and static fake status bar.
- Implement the required static pages and modal states with enough navigation to preview them.
- Keep UI code componentized so later work can attach real hot water, U净, order, scan, and account behavior.
- Keep phone content constrained to about 430dp and centered on wider screens.

**Non-Goals:**

- No real login, scan, hot water, washing, payment, or order backend calls.
- No WebView.
- No XML layouts for the redesigned screens.
- No redesign beyond the references; avoid generic Material dashboard styling.
- No tablet-specific two-column layout.

## Decisions

1. **Use Kotlin + Jetpack Compose as the new UI layer.**

   Compose matches the requested component model and makes it easier to create reusable page sections, cards, fake status bars, and custom decorative layouts. The existing Java implementation can remain as reference code during the prototype, but the visual prototype should not depend on Java View screens.

2. **Use Material 3 only as a foundation, not as the visible style.**

   Material 3 will provide base APIs and interaction primitives, but colors, shapes, buttons, cards, top bars, and tab bars will be custom-styled to match the screenshots.

3. **Create a small app navigation model for static pages.**

   Bottom tabs will switch between 功能、订单、设备、我的. Secondary pages such as 洗衣下单、订单详情、设备菜单弹窗、添加洗衣机弹窗、空设备页 can be reached through simple buttons or local state toggles. This keeps previews and manual testing straightforward without adding a full navigation framework unless needed.

4. **Import assets into Android resources with stable ASCII names.**

   Images from `C:\Users\kazuki\Pictures\shui` should be copied to `res/drawable` using lowercase ASCII resource names. The font `未来圆SC Regular.ttf` should be copied to `res/font` with an ASCII name such as `future_round_sc_regular.ttf`. Compose should load the font through `FontFamily`.

5. **Use a centered adaptive phone container.**

   All pages should render inside an `AdaptivePhoneContainer` with `widthIn(max = 430.dp)` and centered alignment. Small phones use available width; large screens keep the phone-sized design centered.

6. **Draw custom header and bottom navigation shapes in Compose.**

   Header gradients and wave edges can be built with `Box`, `Brush`, and `Canvas` helpers such as `CanvasWave` / `WavyBottomBar`. This avoids forcing the reference design into default Material app bars.

7. **Keep future integration boundaries clean.**

   Static page components should accept plain state/data parameters. Later implementation can replace static values with real ViewModel state without rewriting visual components.

## Risks / Trade-offs

- **Risk: Existing Java real-function test code may be temporarily displaced by Compose prototype work.** → Keep this change scoped as a visual prototype and avoid deleting useful service/API code unless explicitly approved during implementation.
- **Risk: Compose migration requires Gradle changes and Kotlin setup.** → Add the minimum Kotlin/Compose configuration needed for the app module and verify with `assembleDebug`.
- **Risk: Asset names with Chinese characters or spaces may not compile as Android resources.** → Copy assets into resource folders using ASCII snake_case names.
- **Risk: Exact 1:1 visual matching is hard without measuring screenshots.** → Use the provided screenshots as the visual source of truth, inspect them repeatedly, and tune spacing, colors, and image sizes after screenshot verification.
- **Risk: Font rendering may differ across devices.** → Use the local font everywhere and simulate bold with `FontWeight.Bold` where needed.
- **Risk: Bottom navigation may overlap scroll content.** → Give scrollable content explicit bottom padding matching the fixed tab bar height.
