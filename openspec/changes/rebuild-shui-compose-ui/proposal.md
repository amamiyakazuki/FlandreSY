## Why

The app is moving from the current experimental native UI toward a polished "芙兰水衣" product experience. The immediate need is to rebuild the interface as a static Jetpack Compose prototype that closely matches the provided reference screenshots and can later be connected to the existing hot water, U净, and order logic.

## What Changes

- Rebuild the visible app UI using Kotlin + Jetpack Compose and Material 3 foundations.
- Replace XML/View-based screens for this prototype scope; do not add real backend, login, scan, payment, or order behavior in this change.
- Import and use the provided local image assets and font file.
- Implement static versions of the required pages:
  - Home / 功能 page.
  - 洗衣下单 page.
  - 我的 page.
  - 历史订单 page.
  - 订单详情 page.
  - 选择洗衣机 page.
  - 选择洗衣机 action popup.
  - 添加洗衣机 dialog.
  - 空设备 page.
- Add bottom-tab navigation for 功能、订单、设备、我的, with simple static routing to representative pages.
- Keep the visual style close to the reference images: pink/red theme, rounded cards, light pink borders, decorative pixel/Q-style assets, custom status/header/tabbar styling, and phone-width centered layout.

## Capabilities

### New Capabilities

- `shui-compose-static-ui`: Static Compose UI prototype for the 芙兰水衣 visual redesign, including page structure, components, local assets, font usage, adaptive phone container, and static navigation.

### Modified Capabilities

None.

## Impact

- Affected app module files:
  - Gradle configuration for Kotlin, Compose, Material 3, and resource setup.
  - Main activity entry point.
  - New Compose UI source files and reusable components.
  - Resource directories for copied images and font.
- Existing real hot water/U净 logic should not be wired into this static prototype during this change.
- Future implementation work can connect these Compose screens to existing real services after the visual prototype is accepted.
