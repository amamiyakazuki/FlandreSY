# 2.1.3发布记录

- 用户要求暂停UI阶段，发布2.1.3并同步Release/README；元数据2.1.3+5，两份version.json完全相同，iOS Runner继承Flutter版本，无需修改RunnerTests版本。
- 正式脚本成功产出主APK、ARM64/x64分包与AAB；分析无诊断，129测试通过。实际签名证书与线上2.1.2相同，包名com.flandresy，APK未启用debuggable。
- 主APK SHA256：c3481a405d16c406b371ee15123b8a9d7e989e1e236cec58f12e8f13e6f16719。
- ARM64 SHA256：9a49b4b4d47a56ab1d185b6df326c4279bc2097181442af8fda3565c9e2e67db。
- x64 SHA256：ab5440044fbbb9f41e4b738eab72814661a85ae841f8e72444ae03f75765e3a7。
- AAB SHA256：d0d96084991ff3c78fbc3c66f19d998475864f2298f8a50119a8a1f5a107cf80。
- 升级沿用相同文件类型（主版本码5/ARM64 2005/x64 4005），不要为专用包改装主包而卸载数据。发布前先上传完整资产，再公开Release及main清单。
- UI未实现；真实支付按用户决定不验收；热水现场通过来自用户反馈。相对签名路径解析不一致列为后续项，本机绝对路径不受影响。
