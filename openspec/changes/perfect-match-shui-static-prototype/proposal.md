## Why

当前 Compose 静态界面需要进一步对齐 `refer` 参考截图，重点从“可运行原型”提升为“视觉尽量 1:1 还原”的 Android App 原型。

本次变更用于固定视觉还原范围、资源使用方式和验收标准，避免实现时自由发挥导致偏离截图风格。

## What Changes

- 使用 Kotlin + Jetpack Compose + Material 3 基础能力实现静态 Android App 原型。
- 复刻首页、洗衣下单、我的、历史订单、订单详情、选择洗衣机、设备菜单弹窗、添加洗衣机弹窗、空设备页。
- 使用 `refer` 截图作为视觉依据，使用本地 `image` 图片素材和 `font/未来圆SC Regular.ttf` 字体。
- 保留手机布局最大宽度约 430dp，大屏居中显示，不做平板双栏。
- 绘制静态状态栏、红粉渐变 Header、波浪底部导航、浅粉背景、圆角卡片、浅粉边框和像素风装饰。
- 底部 Tab 支持首页、订单、设备、我的的静态切换，二级页面通过简单入口跳转。
- 不接入真实登录、扫码、支付、订单、热水或洗衣接口。

## Capabilities

### New Capabilities

- `shui-static-visual-prototype`: 定义芙兰水衣静态 Compose 原型的页面范围、视觉还原要求、资源使用、导航行为和验收标准。

### Modified Capabilities

- 无。

## Impact

- 主要影响 `app/src/main/java/com/kazuki/zhulihotwater/ui/` 下的 Compose UI 文件。
- 可能调整 `MainActivity` 的入口展示、主题和状态栏处理。
- 可能补齐或替换 `app/src/main/res/drawable/` 与 `app/src/main/res/font/` 中的本地资源。
- 不修改真实热水、U净洗衣、支付、BLE、Widget 或网络接口逻辑。
