# 2.1.4 发布记录

- 用户2026-09-28报告测试正常并确认正式发布2.1.4+6；包含2.1.3之后全部旧订单/账号可用性与登出/首页等宽/热水展示和详情排版修复。
- README、pubspec、两份version.json及docs/releases/2.1.4.md同步；不升级依赖，不改真实支付/BLE行为。
- 正式发布脚本成功，静态分析通过，203测试通过/1可选截图跳过；独立复核三个APK均com.flandresy/2.1.4、非debuggable，code=6/2006/4006，签名与2.1.3一致。AAB jarsigner通过（自签/无时间戳正常告警），Flutter实际ABI为ARM64/x64。
- ARM64 SHA256：10631198450847f35a10ecce661e59e72562afc7814e21f754622210a3c65fc5。
- 主APK SHA256：3cdeaf2aa235753fa90dcdcb23dd911f05ccc95f47cc0c6a36e9fb5d066184a5。
- x64 SHA256：cea2a4c44d00a25fe1d6befe1f7a039dbbf8ca1ad478abf9d310dd031013339e。
- AAB SHA256：1baa8e80689c89ecc537fa83bf93900582465ecb36c4071bf08bd6c2dd1bbff7。
- 既有KGP未来兼容警告非本次阻断。正式脚本clean已移除之前Debug产物；需要Debug时另行构建，不能继续引用旧路径为有效文件。
