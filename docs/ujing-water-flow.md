# U净饮水抓包流程文档

本文整理自历史抓包 `apk_inspect/ujing_login.mitm`。所有接口均为抓包中实际出现过的饮水相关请求。

敏感信息说明：

- 文档不保存 `Authorization` token。
- 手机号、支付签名等敏感字段不记录原值。
- 请求均依赖 U净登录态，即请求头需要 `Authorization: Bearer ...`。

## 基础信息

基础域名：

```text
https://phoenix.ujing.online
```

饮水二维码格式：

```text
http://q.ujing.com.cn/ed/index.html?cd=0011202108055265
```

其中 `cd` 是饮水设备码。后续创建饮水订单时，它会作为 `deviceId` 传入。

抓包中的服务主体：

```text
serviceSubjectId = 37810
serviceSubjectName = 武汉理工大学.马房山校区
storeId = 63199627046cb84fd7c9f7ba
moduleType = 6
```

## 总流程

饮水完整链路是：

```text
识别二维码
-> 根据 cd 确认校区/店铺
-> 查询余额和小票配置
-> 购买小票
-> 再次扫码/确认设备
-> 创建饮水订单
-> 用户在机器上按按钮接水/停止
-> 轮询订单详情，获取扣费结果
```

当前抓包没有发现网络层面的“开始出水”或“停止出水”接口。饮水机的出水/停水动作由现实设备按钮完成，App 侧主要负责创建订单和查询扣费结果。

## 1. 识别饮水二维码

接口：

```http
POST /api/v1/home/scanCode
```

请求体：

```json
{
  "qrCode": "http://q.ujing.com.cn/ed/index.html?cd=0011202108055265"
}
```

响应关键字段：

```json
{
  "code": 0,
  "message": "",
  "data": {
    "service": "water",
    "path": "water/home.js",
    "qrCode": "http://q.ujing.com.cn/ed/index.html?cd=0011202108055265"
  }
}
```

用途：

- 判断二维码属于饮水服务。
- `service=water` 表示进入饮水模块。
- `path=water/home.js` 是官方 App 的饮水页面入口。

## 2. 确认校区/店铺

接口：

```http
POST /api/v1/water/serviceSubject/changeWithScan
```

请求体：

```json
{
  "cd": "0011202108055265"
}
```

响应关键字段：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "oldServiceSubjectId": 37810,
    "newServiceSubjectId": 37810,
    "newServiceSubjectName": "武汉理工大学.马房山校区",
    "storeId": "63199627046cb84fd7c9f7ba",
    "balance": 0,
    "giftBalance": 0,
    "forceRecharge": 10,
    "rechargeTipAmount": 30,
    "maxWaterAmount": 0,
    "channelConfig": 0,
    "channelConfig2": [1],
    "moduleType": 6,
    "waterForceSmartCard": 1
  }
}
```

用途：

- 通过设备码 `cd` 确认所属校区、店铺和饮水配置。
- 这是“扫码后确认区域”的关键接口。
- 后续买小票、创建订单都依赖这里确认出的 `serviceSubjectId` 和 `storeId`。

## 3. 查询饮水首页信息

接口：

```http
GET /api/v1/app/water/serviceSubject/currentInfo
```

响应关键字段：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "ServiceSubjectId": 37810,
    "ServiceSubjectName": "武汉理工大学.马房山校区",
    "balance": 0,
    "giftBalance": 0,
    "category": [3, 4],
    "forceRecharge": 10,
    "rechargeTipAmount": 30,
    "maxWaterAmount": 0,
    "waterForceSmartCard": 0
  }
}
```

用途：

- 查询当前饮水服务主体。
- 查询小票余额。
- 抓包显示，买 10 元小票后 `balance` 从 `0` 变为 `1000`，因此余额大概率以“分”为单位。

## 4. 买小票前准备

### 4.1 查询饮水红包余额

接口：

```http
GET /api/v1/redpackets/totalAmount?type=6
```

响应关键字段：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "balance": 0
  }
}
```

用途：

- 查询饮水类型红包余额。
- `type=6` 对应饮水。

### 4.2 查询服务主体详情

接口：

```http
GET /api/v1/app/serviceSubject/getDetailById?id=37810
```

响应关键字段：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "id": 37810,
    "name": "武汉理工大学.马房山校区",
    "isOpen": 1,
    "waterOrderChannelConf": 0,
    "morePayWay": 1
  }
}
```

用途：

- 查询校区/服务主体详细配置。
- 包含饮水支付配置和是否开放。

### 4.3 查询饮水下单渠道

接口：

```http
POST /api/v1/water/orderChannel
```

请求体：

```json
{
  "serviceSubjectId": 37810
}
```

响应关键字段：

```json
{
  "code": 0,
  "message": "",
  "data": {
    "channel": 0,
    "forceRemind": 0
  }
}
```

用途：

- 查询饮水订单渠道配置。

### 4.4 查询小票余额

接口：

```http
GET /api/v1/bill/user/balance?serviceSubjectId=37810
```

响应关键字段：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "id": 73088322,
    "serviceSubjectId": 37810,
    "serviceSubjectName": "武汉理工大学.马房山校区",
    "giftBalance": 0,
    "category": [3, 4],
    "waterOnlySinglePay": 0,
    "alipayMiniBuyBillEnable": 1
  }
}
```

用途：

- 查询用户在该校区下的小票账户。

### 4.5 查询公告提示

接口：

```http
POST /api/v1/app/bill/notice/check
```

请求体：

```json
{}
```

响应关键字段：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "showFlag": false
  }
}
```

用途：

- 判断买小票前是否显示公告。
- 抓包中 `showFlag=false`，所以没有实际阻塞。

### 4.6 查询可购买小票金额

接口：

```http
GET /api/v1/app/bill/recharge/itemV2?serviceSubjectId=37810
```

响应关键字段：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "list": [
      {
        "id": 1,
        "price": 1000,
        "giftAmount": 0
      },
      {
        "id": 2,
        "price": 2000,
        "giftAmount": 0
      }
    ]
  }
}
```

用途：

- 查询小票面额。
- 抓包中只有 10 元和 20 元。
- `price=1000` 表示 10.00 元，`price=2000` 表示 20.00 元。

## 5. 小票支付流程

### 5.1 查询支付方式

接口：

```http
GET /api/v1/payment/methods?include=&serviceSubjectId=37810&creativeNumber=2898011024273709388&fromType=ticketPay
```

响应关键字段：

```json
{
  "code": 0,
  "message": "请求成功",
  "data": {
    "channels": [
      {
        "channel": "unionPay",
        "name": "银联",
        "isDefault": true,
        "branchType": 1
      },
      {
        "channel": "dyPay",
        "name": "抖音支付",
        "branchType": 0
      },
      {
        "channel": "wechatPay",
        "name": "微信支付",
        "branchType": 0
      },
      {
        "channel": "alipay",
        "name": "支付宝支付",
        "branchType": 0
      },
      {
        "channel": "cmbPayH5",
        "name": "一网通支付",
        "branchType": 0
      }
    ]
  }
}
```

用途：

- 查询买小票可用支付方式。
- 抓包中包含银联、抖音、微信、支付宝、一网通。

### 5.2 创建小票支付订单

接口：

```http
POST /api/v1/bill/recharge/create
```

抓包请求体，微信支付示例：

```json
{
  "serviceSubjectId": 37810,
  "totalFee": 1000,
  "channel": "wechatPay",
  "redPacketId": 0,
  "branchType": 0,
  "payVersion": 1
}
```

响应关键字段：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "jumpToQuery": false,
    "payType": "wechatPayMidea",
    "skipPay": false,
    "payInfo": {
      "appid": "...",
      "partnerid": "...",
      "prepayid": "...",
      "noncestr": "...",
      "timestamp": "...",
      "package": "Sign=WXPay",
      "sign": "..."
    }
  }
}
```

用途：

- 创建小票充值订单。
- 返回第三方支付参数。
- 抓包中实际跑通的是微信小票支付。

注意：

- 如果使用支付宝，小票支付大概率仍是同一个接口，只是 `channel` 改为 `alipay`。
- 但当前饮水小票抓包中只确认了 `wechatPay` 的创建结果。

### 5.3 支付后查询余额

接口：

```http
GET /api/v1/app/water/serviceSubject/currentInfo
```

支付成功后响应关键字段：

```json
{
  "ServiceSubjectId": 37810,
  "ServiceSubjectName": "武汉理工大学.马房山校区",
  "balance": 1000
}
```

用途：

- 确认小票余额到账。
- `balance=1000` 表示 10 元小票余额。

### 5.4 查询小票购买记录

接口：

```http
POST /api/v1/app/bill/recharge/list
```

请求体：

```json
{
  "serviceSubjectId": 37810,
  "skip": 0,
  "limit": 10,
  "businessType": 1,
  "beforeThreeMonths": false
}
```

响应关键字段：

```json
{
  "code": 0,
  "message": "success",
  "data": [
    {
      "id": 910504474,
      "orderNo": "...",
      "totalFee": 1000,
      "payFlag": 2,
      "serviceSubjectId": 37810,
      "rechargeType": 1,
      "rechargeChannel": 1200,
      "rechargeChannelName": "购票（微信）",
      "actualIncome": 994
    }
  ]
}
```

用途：

- 查询小票购买记录。
- 这是小票充值历史，不是饮水消费历史。

## 6. 创建饮水订单

接口：

```http
POST /api/v1/water/createWaterOrder
```

请求体：

```json
{
  "deviceId": "0011202108055265"
}
```

响应关键字段：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "code": 0,
    "id": "",
    "orderId": 1102876060,
    "orderNo": "...",
    "maxSeconds": 0,
    "orderType": 6,
    "message": "",
    "token": "",
    "deviceId": "9732f34d7804d72c7d3a98ae9921723c"
  }
}
```

用途：

- 创建一次饮水订单。
- 请求中的 `deviceId` 使用二维码里的 `cd`。
- 响应中的 `deviceId` 是服务端内部设备 ID。
- `orderId` 是后续查询订单状态的核心字段。

## 7. 查询饮水订单详情

接口：

```http
POST /api/v1/water/waterOrderDetail
```

请求体：

```json
{
  "orderId": 1102876060
}
```

### 7.1 刚创建订单时

响应关键字段：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "id": 1102876060,
    "orderNo": "...",
    "serviceSubjectId": 37810,
    "serviceSubjectName": "武汉理工大学.马房山校区",
    "storeId": "63199627046cb84fd7c9f7ba",
    "storeName": "学海7舍-5",
    "deviceId": "9732f34d7804d72c7d3a98ae9921723c",
    "deviceNo": "070501",
    "orderStatus": 0,
    "orderStatusName": "订单创建",
    "statusRemark": "订单创建",
    "payTypeName": "小票支付",
    "payModeName": "小票支付",
    "sceneIdName": "先取水后结账",
    "payFlag": 0,
    "payPrice": 0,
    "payment": 0,
    "actualIncome": 0
  }
}
```

用途：

- 确认饮水订单已创建。
- 此时还没有实际用水量，也没有扣费。

### 7.2 现实机器接水完成后

用户在现实饮水机上按按钮接水、再次按按钮停止后，继续查询同一个接口。

响应关键字段：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "id": 1102876060,
    "orderStatus": 50,
    "orderStatusName": "取水正常完成",
    "statusRemark": "取水正常完成",
    "warmWaterML": 133,
    "waterSeconds": 2,
    "duration": 0.45,
    "payPrice": 0.02,
    "payment": 0.02,
    "actualIncome": 0.02,
    "rechargeAmount": 0.02,
    "payFlag": 1,
    "payTypeName": "小票支付",
    "payModeName": "小票支付",
    "activePay": 0
  }
}
```

用途：

- 获取最终用水量。
- 获取扣费金额。
- 判断订单是否完成。

抓包中的实际结果：

```text
warmWaterML = 133
waterSeconds = 2
payment = 0.02
balance: 1000 -> 998
```

说明：

- 小票余额单位是分。
- 订单详情里的 `payment=0.02` 是元。
- 余额 `998` 表示剩余 9.98 元。

## 8. 饮水历史记录

抓包中已确认的历史接口只有“小票购买记录”：

```http
POST /api/v1/app/bill/recharge/list
```

它记录的是买小票，不是接水消费。

APK 的饮水 bundle 中能看到疑似饮水消费历史接口：

```text
water/waterOrderList
water/waterOrderDetail
```

其中 `water/waterOrderDetail` 已被抓包确认。

但是本次历史抓包没有实际抓到 `water/waterOrderList` 的请求和响应，因此后续实现“饮水消费历史列表”时，不能直接猜参数，需要补抓一次官方 App 的饮水消费记录页。

## 9. 当前能安全实现的能力

基于已确认抓包，可以实现：

- 识别饮水二维码。
- 根据二维码确认校区和店铺。
- 查询饮水小票余额。
- 查询小票可购买金额。
- 创建小票支付订单。
- 支付后查询余额。
- 创建饮水订单。
- 查询饮水订单详情。
- 轮询订单详情，拿到完成状态、用水量、扣费金额。
- 查询小票购买记录。

暂时不能安全实现：

- 网络接口直接控制饮水机开始出水。
- 网络接口直接控制饮水机停止出水。
- 饮水消费历史列表。

原因：

- 抓包中没有开始/停止出水接口。
- 饮水机出水和停止由现实设备按钮完成。
- 抓包中没有 `water/waterOrderList` 的实际请求参数和响应。

## 10. 推荐实现顺序

后续接入小工具时，建议按这个顺序：

1. 复用 U净登录态。
2. 扫码或读取保存的饮水二维码。
3. 调用 `home/scanCode` 判断是否为饮水码。
4. 调用 `water/serviceSubject/changeWithScan` 确认校区/店铺。
5. 调用 `app/water/serviceSubject/currentInfo` 查询余额。
6. 如果余额不足，引导购买小票。
7. 买小票时先调用 `app/bill/recharge/itemV2` 获取金额。
8. 调用 `payment/methods` 展示可用支付方式。
9. 调用 `bill/recharge/create` 创建支付。
10. 支付完成后重新查询余额。
11. 调用 `water/createWaterOrder` 创建接水订单。
12. 进入订单状态页，轮询 `water/waterOrderDetail`。
13. 当 `orderStatus=50` 或 `statusRemark=取水正常完成` 时，显示完成金额和用水量。

