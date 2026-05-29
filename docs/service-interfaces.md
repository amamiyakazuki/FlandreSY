# Service Interfaces

本文档记录芙兰水衣后续接入真实服务时需要遵守的接口、状态和生命周期边界。

来源分级：

- **已验证源码**：当前项目代码中存在并被调用。
- **历史记录确认**：来自 `P_PLAN` 和 OpenSpec 记录。
- **待捕获**：当前没有完整代码或抓包证据，不能按已实现功能处理。

## Runtime Boundary

当前 `MainActivity.kt` 和 Compose UI 是静态原型。预览、静态按钮、静态 Tab、设备弹窗和订单页不得直接调用真实网络、BLE、扫码、下单或支付接口。

后续集成时，真实动作应从运行时 ViewModel 或 action 层发起：

- UI 只表达用户意图，例如 start hot water、stop hot water、scan washer、create order、pay order。
- ViewModel 检查登录状态、设备状态、权限和当前订单状态。
- Service/API 层执行网络、BLE、支付 SDK 和回调处理。
- Compose Preview 使用 fake state，不持有真实 token、手机号、设备号、订单号或 BLE 会话。

## Shared Storage

当前真实功能共用 SharedPreferences 名称 `zhuli_hotwater`。

| Key | 所属 | 内容 | 来源 |
| --- | --- | --- | --- |
| `phone` | 热水 | 住理生活手机号 | 已验证源码 |
| `device_id` | 热水 | 热水设备 ID，默认 `1006445` | 已验证源码 |
| `session` | 热水 | `ZhuliSession` JSON | 已验证源码 |
| `last_device_id` | 热水 | 上次开水设备 | 已验证源码 |
| `last_isn` | 热水 | 上次 BLE 握手返回的 `isn`，关水依赖它 | 已验证源码 |
| `last_order_id` | 热水 | 上次热水订单 ID | 已验证源码 |
| `ujing_phone` | U净 | U净手机号 | 已验证源码 |
| `ujing_session` | U净 | `mobile/token/userId/serviceSubjectId` JSON | 已验证源码 |
| `ujing_washer_qr` | U净洗衣 | 最近一次洗衣二维码 URL | 已验证源码 |
| `ujing_wechat_appid` | U净支付 | 微信支付回调用 appId | 已验证源码 |
| `ujing_last_order_id` | U净支付 | 微信支付回调用订单 ID | 已验证源码 |

不要把用户密码、验证码、token、订单实值写入文档或日志以外的长期说明里。日志仅用于本机调试。

## Zhuli Hot Water

### Ownership

真实热水功能目前由以下类承载：

- `LegacyHotwaterActivity`：旧 UI、登录、开水、关水、BLE 会话和 `ZhuliApi`。
- `HotwaterActionRunner`：后台/Widget 触发开关水的复用流程。
- `HistoryActivity`：近 30 天消费记录。
- `HotwaterActionService` / `HotwaterWidgetProvider`：从 Widget 进入前台服务执行。

### Login Session

登录接口：

| 项 | 值 |
| --- | --- |
| Method | `GET` |
| URL | `https://pm.whxinna.com/webapi/users/login` |
| 签名 | 平台 key `PLATFORM_KEY`，参数排序后 MD5 |
| 参数 | `appVersion=3.11.51`、`systemType=Android`、`systemVersion`、`deviceModel`、`deviceToken`、`pwd`、`phone`、`code`、`base64_user_extends`、`timestamp`、`noncestr`、`sign` |
| 重要返回 | `platform_token`、`user_info.id`、`user_info.identity_code`、`server_info.projectname`、`server_info.server_addr`、`server_info.server_appid`、`server_info.server_id`、`server_info.session_secret/appsecret` |
| 来源 | 已验证源码 |

`server_addr` 是后续业务接口 base URL，缺失时回退 `https://f5-zhuli.whxinna.com`。业务签名优先使用 `session_secret`，缺失时使用 `appsecret`。

热水 session 缓存在 `zhuli_hotwater/session`。如果接口错误包含 `api_sign_error`，当前代码会清除缓存，要求重新登录。

### Business Signing

业务接口通用参数：

- `timestamp`
- `noncestr`
- `user_id`
- `identitycode`，存在时添加
- `pid`，来自 `server_appid`，存在时添加
- `appid`，来自 `server_id`，存在时添加
- `sign`，使用业务 secret 生成

签名规则：排除 `sign`，按 key 排序，忽略空值，将值中的引号和空格移除，拼接 `k=v`，末尾追加 `&key=<secret>`，取 UTF-8 MD5 大写十六进制。

### Start Hot Water Flow

触发条件：

- 用户在旧热水入口点击开水，或 Widget/前台服务调用 `HotwaterActionRunner.start`。
- 必须有手机号、设备 ID。
- 如果没有缓存 session，必须提供密码完成登录。
- 必须具备 BLE 扫描和连接权限，且靠近目标设备。

生命周期：

1. 读取 `phone`、`device_id`，保存到 SharedPreferences。
2. 读取 `session`；没有缓存时调用住理登录。
3. 调用 `device/get_by_id` 获取设备 BLE 名称、MAC、设备类型。
4. 扫描 BLE，按 `ble_name`、`ble_mac` 或名称包含 `XN` 的 fallback 匹配。
5. 连接 GATT，发现 service/characteristic，开启 read notify。
6. 调用 `device/ble/create_hand_shake_cmd` 取得握手 hex。
7. BLE 写握手指令，等待 `cmd_hand_shark`。
8. 调用 `device/ble/heart_shark_response`，获得 `isn` 和可选 `ratecmd`。
9. 保存 `last_device_id`、`last_isn`。
10. 如果存在 `ratecmd` 且设备类型不是 `3/5`，写入 `cmd_set_rate`。
11. 如果设备类型不是 `3/5` 且握手 `result != 3`，调用 `device/ble/create_history_order_cmd`，写入 `cmd_history_order`，再用 `consume/ble/end_consume_response` 同步历史。
12. 调用 `consume/create_order` 创建订单，取得 `app_bytes` 和 `order_id`。
13. 保存 `last_order_id`。
14. BLE 写 `app_bytes`，等待 `cmd_start_order`。
15. 调用 `consume/ble/start_consume_response` 确认启动。
16. 关闭 BLE 连接。

### Stop Hot Water Flow

触发条件：

- 用户在旧热水入口点击关水，或 Widget/前台服务调用 `HotwaterActionRunner.stop`。
- 必须已有缓存 session。
- 必须有当前设备对应的 `last_isn`。如果不是本 App 成功开水过，当前代码无法可靠关水。

生命周期：

1. 读取 `phone`、`device_id`、`session` 和 `last_isn`。
2. 调用 `device/get_by_id` 获取 BLE 名称和 MAC。
3. 连接 BLE。
4. 调用 `consume/ble/create_end_consume_cmd` 取得结束 hex。
5. BLE 写结束指令，等待 `cmd_end_consume`。
6. 调用 `consume/ble/end_consume_response`。
7. 清除 `last_device_id`、`last_isn`、`last_order_id`。
8. 关闭 BLE 连接。

### Hot Water Endpoints

| Flow | Method | Path | Required state | Important params | Important response | Side effect |
| --- | --- | --- | --- | --- | --- | --- |
| 登录 | `GET` | `https://pm.whxinna.com/webapi/users/login` | 手机号、密码 | `phone`、`pwd`、平台签名参数 | `user_info`、`server_info` | 缓存 session |
| 设备详情 | `GET` | `/webapi/v1/device/get_by_id` | `ZhuliSession` | `id` | `ble_name`、`ble_mac`、`device_type` | 决定 BLE 目标 |
| 创建握手 | `GET` | `/webapi/v1/device/ble/create_hand_shake_cmd` | `ZhuliSession`、设备 ID | `device_id` | hex 字符串 | 需要写入 BLE |
| 握手响应 | `GET` | `/webapi/v1/device/ble/heart_shark_response` | BLE 握手返回 hex | `device_id`、`hex` | `isn`、`ratecmd`、`result` | 保存 `isn`，可写费率 |
| 历史订单指令 | `GET` | `/webapi/v1/device/ble/create_history_order_cmd` | `isn` | `device_id`、`isn` | hex 字符串 | 可同步旧订单 |
| 创建订单 | `GET` | `/webapi/v1/consume/create_order` | `isn` | `device_id`、`isn`、`net_type=4`、`staff_id`、`money=0`、`consume_value=0` | `app_bytes`、`order_id` | 创建热水消费订单 |
| 启动确认 | `GET` | `/webapi/v1/consume/ble/start_consume_response` | 订单和 BLE 启动响应 | `device_id`、`order_id`、`hex` | 启动结果 JSON | 服务端确认开水 |
| 结束指令 | `GET` | `/webapi/v1/consume/ble/create_end_consume_cmd` | `isn` | `device_id`、`isn` | hex 字符串 | 需要写入 BLE |
| 结束确认 | `GET` | `/webapi/v1/consume/ble/end_consume_response` | BLE 结束响应 | `device_id`、`hex` | 结束结果 JSON | 服务端确认关水/同步 |
| 消费历史 | `GET` | `/webapi/v1/consume/list_record_by_staffid` | `ZhuliSession` | `staff_id`、`start`、`end` | array 或包裹 array | 展示历史 |

### BLE Contract

| 项 | 值 |
| --- | --- |
| Service UUID | `0000ff12-0000-1000-8000-00805f9b34fb` |
| Write UUID | `0000ff01-0000-1000-8000-00805f9b34fb` |
| Read UUID | `0000ff02-0000-1000-8000-00805f9b34fb` |
| CCCD UUID | `00002902-0000-1000-8000-00805f9b34fb` |
| Scan timeout | 8 秒 |
| GATT retry | 最多 3 次 |
| GATT connect timeout | 10 秒 |
| BLE response timeout | 6 秒 |

响应类型由第三个字节判断：

| Byte | Type |
| --- | --- |
| `1` | `cmd_hand_shark` |
| `2`、`67` | `cmd_history_order` |
| `3`、`64` | `cmd_start_order` |
| `4`、`5`、`65` | `cmd_end_consume` |
| `16` | `cmd_set_rate` |
| `240` | `error_crc` |

### Hot Water Failure Handling

- 手机号为空：要求先登录。
- 设备 ID 为空：阻止执行。
- session 缺失且没有密码：要求先打开 App 登录一次。
- `api_sign_error`：清除热水 session。
- 蓝牙未开启、权限缺失、扫不到设备、GATT 连接失败、找不到 service/characteristic、写入失败、响应超时：向用户显示错误并写日志。
- 开水后必须保存 `isn`，否则关水流程不能继续。

## Ujing Washer

### Ownership

- `UjingApi`：封装 HTTP、session、cookie、请求头、洗衣订单和支付接口。
- `UjingWasherTestActivity`：最小测试界面，串起登录、扫码、套餐、下单、支付、取消。
- `WXPayEntryActivity`：微信支付 SDK 回调记录。

### Request Headers

所有 U净请求使用基础地址 `https://phoenix.ujing.online/api/v1/`。

通用请求头：

- `x-mobile-brand: HUAWEI`
- `x-mobile-id:`
- `x-app-code: ZA` 或 `BA`
- `x-app-version: 2.4.14`
- `x-mobile-model: HBN-AL00`
- `content-type: application/json` 或 `application/json; charset=utf-8`
- `accept-encoding: identity`
- `user-agent: okhttp/4.3.1`
- `weex-version: 1.1.68`，洗衣相关接口使用
- `authorization: Bearer <token>`，登录后接口使用
- `cookie`，来自本次运行期间服务端 Set-Cookie

`ensureOk` 规则：响应 JSON 的 `code` 必须为 `0`，否则抛出 `message`。

### Login Flow

触发条件：

- 用户输入手机号，点击获取验证码。
- 用户输入验证码，点击登录。

接口：

| Flow | Method | Path | Required state | Params/body | Important response | Side effect |
| --- | --- | --- | --- | --- | --- | --- |
| 获取验证码 | `GET` | `captcha` | 手机号 | `mobile`、`type=1`、`sessionId=AFS_SWITCH_OFF`、`token=AFS_SWITCH_OFF`、`sig=AFS_SWITCH_OFF` | `code=0` | 服务端发送短信 |
| 登录 | `POST` | `login` | 手机号、验证码 | body: `mobile`、`captcha` | `mobile`、`token`、`userId`、`serviceSubjectId` | 缓存 `ujing_session` |

### Washer Scan And Program Flow

触发条件：

- 用户已登录 U净。
- 用户输入洗衣二维码 URL。

生命周期：

1. 调用 `devices/scanWasherCode`，body 为 `qrCode`。
2. 读取 `data.result` 中的设备信息。
3. 如果 `createOrderEnabled=false`，只展示原因，不继续下单。
4. 调用 `app/washer/devices/program/info` 获取设备套餐和门店信息。
5. 默认选择 `workModelId=1`；如果不存在，选择返回列表第一个套餐。

接口：

| Flow | Method | Path | Required state | Params/body | Important response | Side effect |
| --- | --- | --- | --- | --- | --- | --- |
| 扫码 | `POST` | `devices/scanWasherCode` | U净 token、二维码 | body: `qrCode` | `deviceId`、`deviceTypeId`、`moduleType`、`status`、`reason`、`createOrderEnabled`、`needSync` | 决定是否可下单 |
| 套餐 | `GET` | `app/washer/devices/program/info` | U净 token、设备 | query: `deviceId` | `deviceId`、`deviceNo`、`deviceTypeId`、`deviceTypeName`、`storeId`、`storeName`、`deviceWashModel` | 提供下单参数 |

### Washer Order Flow

触发条件：

- 已登录。
- 已扫码并获取 `ProgramInfo`。
- `ProgramInfo.storeId` 不为空。
- 用户选择 `deviceWashModelId` 和 `washTemperatureId`。

生命周期：

1. 如果没有 `ProgramInfo`，测试页会重新扫码并拉套餐。
2. 调用 `orders/create` 创建待支付订单。
3. 读取 `orderId`。
4. 调用 `orders/{orderId}/detail` 展示设备号、状态和金额。

接口：

| Flow | Method | Path | Required state | Params/body | Important response | Side effect |
| --- | --- | --- | --- | --- | --- | --- |
| 创建订单 | `POST` | `orders/create` | U净 token、套餐信息 | body: `type=1`、`deviceTypeId`、`deviceId`、`deviceWashModelId`、`storeId`、`washTemperatureId` | `orderId`、`deviceId` | 创建待支付洗衣订单 |
| 订单详情 | `GET` | `orders/{orderId}/detail` | U净 token、订单 ID | path: `orderId` | `deviceNo`、`statusRemark/status`、`payPrice` | 展示状态 |
| 取消订单 | `POST` | `orders/{orderId}/cancel` | U净 token、订单 ID | path/body: `orderId` | `code=0` | 当前订单作废 |
| 启动洗衣机 | `GET` | `orders/{orderId}/control/start` | U净 token、已支付订单 | path: `orderId` | `code=0`、`data={}` | 用户在支付后的订单详情页手动确认启动 |
| 提前停止 | `GET` | `orders/{orderId}/control/stop` | U净 token、启动中/运行中订单 | path: `orderId` | `code=0`、`data={}` | 用户提前停止洗衣机 |

已抓包确认的状态：

- 创建后未支付/预约：`status=10`，`statusRemark=已预约`，`payFlag=0`。
- 支付后未启动：`status=20`，`statusRemark=已支付`，`payFlag=1`。
- 调用 `control/start` 后启动中：`status=21`，`statusRemark=启动中`，有 `userClickWashStartTime`。
- 实际运行中：`status=40`，`statusRemark=运行中`，有 `remainTime`、`washStartTime`。
- 调用 `control/stop` 后完成：`status=50`，`statusRemark=订单完成`，有 `finishType=2`、`manualFinishTime`、`washEndTime`。

### Payment Flow

触发条件：

- 已登录。
- 已有待支付订单。
- 已有 `ProgramInfo`。
- 用户选择支付 channel，默认 `alipay`。

生命周期：

1. 可选调用 `payment/methods` 查看可用 channel。
2. 调用 `payment/arguments` 获取支付参数。
3. 如果 `payInfo.h5_url` 存在，使用系统 Intent 打开 H5 链接。
4. 如果 `payInfo.orderInfo` 存在，调用支付宝 SDK `PayTask.payV2(orderInfo, true)`，之后查询订单详情。
5. 如果 `payInfo.prepayid/prepayId` 存在，构造微信 `PayReq` 并调用 `IWXAPI.sendReq`。
6. 微信回调由 `WXPayEntryActivity` 记录，测试页不保证自动刷新订单。
7. 微信 H5 探测会尝试多个历史候选 channel，成功时打开第一个可识别链接。

接口：

| Flow | Method | Path | Required state | Params/body | Important response | Side effect |
| --- | --- | --- | --- | --- | --- | --- |
| 支付方式 | `GET` | `payment/methods` | U净 token、订单、套餐 | `include`、`serviceSubjectId`、`deviceId`、`creativeNumber=2898011024273709388`、`orderId` | `data.channels` | 展示可用渠道 |
| 支付参数 | `GET` | `payment/arguments` | U净 token、订单 ID、channel | `channel`、`orderId`、`couponId`、`isUseRedPacket=false`、`redPacketId=0`、`alipayF2FNoAds=false`、`branchType=0`、`jumpToAliMini=false`、`payVersion=1` | `data.payInfo` | 拉起 H5/支付宝/微信 |

已测试和风险：

- 支付宝标准 `orderInfo` 已接入 `PayTask.payV2`。是否支付成功需要看 SDK result 和订单详情。
- 微信 SDK 已接入 `PayReq` 和回调 Activity，但可能被商户平台包名、签名或 appId 绑定限制。
- Android 11+ 查询微信安装状态需要 Manifest `queries` 声明 `com.tencent.mm`，当前已添加。
- 微信 H5 channel 只是探测，不是稳定接口契约。

### Payment Callback

`WXPayEntryActivity`：

- 读取 `ujing_wechat_appid` 初始化 `IWXAPI`。
- `onResp` 记录 `type`、`errCode`、`errStr`。
- 当 `type == COMMAND_PAY_BY_WX` 时附带缓存的 `ujing_last_order_id`。
- 回调只写日志，不直接修改 U净订单状态。

## Ujing Drinking Water

状态：**已捕获部分能力**。详细抓包说明见 `docs/ujing-water-flow.md`。

当前已确认可执行饮水扫码识别、校区/店铺确认、余额查询、创建接水订单和查询订单详情。抓包没有发现网络层面的“开始出水”或“停止出水”接口；出水和停水由用户在现实饮水机上按按钮完成，App 侧负责创建订单并查询扣费结果。

已知边界：

- 饮水二维码格式为 `http://q.ujing.com.cn/ed/index.html?cd=...`，其中 `cd` 是创建饮水订单时使用的设备码。
- 饮水订单不能复用洗衣 `orders/create`、`control/start`、`control/stop`。
- 余额不足时，本工具先提示“余额不足，请先在官方 App 充值”，本轮不接入小票充值支付。
- 饮水消费历史列表 `water/waterOrderList` 仍缺实际请求和响应，不能猜参数。

已确认接口：

| Flow | Method | Path | Required state | Params/body | Important response | Side effect |
| --- | --- | --- | --- | --- | --- | --- |
| 识别饮水码 | `POST` | `home/scanCode` | U净 token、二维码 | body: `qrCode` | `service=water`、`path=water/home.js`、`qrCode` | 判断二维码属于饮水模块 |
| 确认校区/店铺 | `POST` | `water/serviceSubject/changeWithScan` | U净 token、`cd` | body: `cd` | `newServiceSubjectId`、`newServiceSubjectName`、`storeId`、`balance`、`moduleType=6` | 确认饮水服务主体 |
| 查询饮水主体 | `GET` | `app/water/serviceSubject/currentInfo` | U净 token | 无 | `ServiceSubjectId`、`ServiceSubjectName`、`balance`、`giftBalance` | 查询余额和主体信息 |
| 创建接水订单 | `POST` | `water/createWaterOrder` | U净 token、余额可用、`cd` | body: `deviceId=<cd>` | `orderId`、`orderNo`、`orderType=6`、内部 `deviceId` | 创建一次现实机器接水订单 |
| 查询接水订单 | `POST` | `water/waterOrderDetail` | U净 token、订单 ID | body: `orderId` | `orderStatus/orderStatusName`、`warmWaterML`、`waterSeconds`、`payment`、`payFlag` | 展示接水状态、用水量和扣费 |

订单状态：

- 刚创建：`orderStatus=0`，`orderStatusName=订单创建`，等待用户在机器上按按钮接水。
- 接水完成：`orderStatus=50`，`orderStatusName/statusRemark=取水正常完成`，返回 `warmWaterML`、`waterSeconds`、`payment`。

## Future Integration Checklist

接入 Compose UI 前必须满足：

- ViewModel 持有显式状态：未登录、登录中、已登录、设备加载中、BLE 连接中、订单创建中、支付中、失败、成功。
- 热水开关按钮必须防重复点击，且开水和关水不能并发。
- BLE 权限、蓝牙开启、定位/附近设备权限必须在 UI 层显式处理。
- 热水关水必须校验 `last_isn`，没有时提示“只能关闭本 App 本次打开的热水”。
- U净下单前必须校验 `createOrderEnabled`、`storeId`、套餐和温度 ID。
- 支付后必须通过订单详情刷新状态，不能只相信 SDK 回调。
- Preview、截图测试、静态设计态必须使用 fake repository，禁止真实 service 注入。

## Source Map

| Area | Source |
| --- | --- |
| 热水登录、业务接口、BLE | `app/src/main/java/com/kazuki/zhulihotwater/LegacyHotwaterActivity.java` |
| 热水后台开关 | `app/src/main/java/com/kazuki/zhulihotwater/HotwaterActionRunner.java` |
| 热水历史 | `app/src/main/java/com/kazuki/zhulihotwater/HistoryActivity.java` |
| U净 HTTP 接口 | `app/src/main/java/com/kazuki/zhulihotwater/UjingApi.java` |
| U净测试页、支付宝、微信 SDK | `app/src/main/java/com/kazuki/zhulihotwater/UjingWasherTestActivity.java` |
| 微信回调 | `app/src/main/java/com/kazuki/zhulihotwater/wxapi/WXPayEntryActivity.java` |
| 静态 Compose UI | `app/src/main/java/com/kazuki/zhulihotwater/MainActivity.kt`、`app/src/main/java/com/kazuki/zhulihotwater/ui/` |
| 历史决策 | `P_PLAN/PLAN.md`、`P_PLAN/part2.md`、`P_PLAN/part3.md`、`P_PLAN/part4.md`、`P_PLAN/part5.md`、`P_PLAN/part6.md`、`P_PLAN/part7.md` |
