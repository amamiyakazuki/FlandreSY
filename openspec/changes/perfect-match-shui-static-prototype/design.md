## Context

项目当前已有 Android 工程、Compose UI 文件、本地图片资源和字体资源。用户本次目标不是普通 Material App，也不是接入真实业务逻辑，而是对照 `refer` 参考截图制作尽可能 1:1 的静态视觉原型。

已有 UI 文件可作为基础，但需要重新核对参考图比例、文字、图片位置、Header/TabBar 波浪、卡片圆角、边框、渐变、字体和小屏/大屏约束。真实热水、U净、支付、Widget 等逻辑保持不动。

## Goals / Non-Goals

**Goals:**

- 用 Kotlin + Jetpack Compose 实现 9 个静态页面/弹窗，并保持组件化。
- 使用本地 `image` 图片素材和 `font/未来圆SC Regular.ttf` 字体，不生成或替换角色图。
- 最大内容宽度约 430dp，大屏居中，小屏按宽度自适应。
- 绘制红粉渐变 Header、底部波浪导航、浅粉背景、圆角卡片和装饰元素；显示系统真实状态栏，但不在 App 内部绘制 9:41、信号、Wi-Fi、电量等假状态栏。
- 支持底部 Tab 静态切换，以及订单详情、洗衣下单、空设备页、弹窗等临时入口。
- 保证 Android Studio Preview 可预览，主入口启动显示首页。

**Non-Goals:**

- 不接入真实扫码、登录、支付、订单、设备、热水或洗衣接口。
- 不新增 WebView 或 XML 页面布局。
- 不做平板双栏布局。
- 不重构真实业务逻辑、BLE、Widget 或支付 SDK。

## Decisions

1. 以现有 Compose UI 为基础做视觉校准，而不是重建整个 Android 工程。
   - 原因：工程已包含 Compose 入口、资源、主题和部分页面结构，继续修正能减少对真实业务代码的影响。
   - 替代方案：新建独立 demo app。缺点是会脱离当前项目入口和后续集成路径。

2. 将视觉系统集中在 `ShuiTheme.kt`、`ShuiComponents.kt`、`ShuiScreens.kt` 一组文件内。
   - 原因：当前项目已有这个分层，便于维护组件化要求，同时避免把静态原型扩散到真实业务类。
   - 替代方案：按页面拆更多文件。后续如果文件过大，可以在用户确认后再拆。

3. Header、底部导航和波浪使用 Compose Canvas/Path 绘制。
   - 原因：参考图里波浪和渐变是关键视觉特征，直接绘制更容易贴近截图。
   - 替代方案：使用图片背景。缺点是不同屏宽适配和文字/按钮叠放更难控制。

4. 图片资源统一使用 `Image(painterResource(...))` 和 `ContentScale.Fit`/固定比例约束。
   - 原因：素材是像素风/Q版图，必须避免拉伸变形。
   - 替代方案：裁剪填充。缺点是容易破坏角色和装饰完整性。

5. 静态导航使用 Compose 内部状态，不引入 Navigation 组件。
   - 原因：页面只是视觉原型，内部状态足以支持 Tab 和临时跳转，依赖更少。
   - 替代方案：引入 Navigation Compose。当前收益不高。

## Risks / Trade-offs

- [Risk] 截图为固定尺寸，Compose 在不同手机宽度上无法做到像素级完全一致 → 用 430dp 最大宽度、固定关键高度、相对 padding 和预览截图对齐来降低偏差。
- [Risk] 字体文件名含中文，资源命名需要 Android 合法化 → 使用 `future_round_sc_regular.ttf` 作为 `res/font` 资源名，但字体来源保持本地文件。
- [Risk] 参考图中部分图标没有独立素材 → 使用 Compose Vector/Canvas/Text 近似绘制，颜色和尺寸按截图调校。
- [Risk] 当前文件可能已有历史实现，直接大改容易影响真实功能入口 → 只改 Compose 静态原型和必要入口，不碰 API、支付、BLE、Widget。
- [Risk] 视觉 1:1 需要反复截图对比 → 分阶段先完成整体结构，再逐页微调并记录差异。
