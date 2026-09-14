
## 归档文档核对（2026-09-09）
- 同步后的用途说明需满足 OpenSpec 严格校验的至少 50 字符约束，已补充范围与行为说明。
- 热水 delta spec 仍引用旧实时接口优先方案，现按用户已确认的持久化会话与订单轮询决策修正。
- 主规格目录为空，账号入口与首页状态的 MODIFIED 声明没有对应基线，改为首次 ADDED 同步。
- 真机权限验证由用户确认完成，未声称本轮由代理执行。

## 账号中心圆形入口遗漏
- 已确认：AccountHubScreen 仍使用旧 AccountCard，路由已接通但未实现用户要求的分散圆形 App 入口。
- 修复范围：仅账号中心入口布局，保留已有账号详情和默认系统行为。
- 已修复并通过入口路由、圆形结构及窄屏大字体测试；此前只检查文字的测试未能发现视觉需求遗漏，现已补齐。
- 验证中修正：测试误 await 同步的 view.reset；798 登录页自动加载验证码有 400ms 模拟延迟，路由测试需推进时钟等待完成。

## 本次变更：account-permissions-and-status-cleanup
- 已接入统一真实权限服务，Shell 请求相机、蓝牙、通知权限，并在恢复前台时刷新；永久拒绝可打开系统设置。
- 默认洗浴系统新增 `none`，账号中心选择不再提前切换；住理/798 登录成功自动设为默认，账号页可取消，U净不改变偏好。
- 删除首页泛化警告、账号中心引导提示及 `GAL REVIEW REQUIRED` 历史标记。
- 热水订单/消费记录能否作为实时状态兜底仍需接口资料确认，暂未实现未知语义之外的猜测逻辑。

## 热水会话方案
- 已处理：热水进行中会话持久化，重启后立即核对并恢复轮询；订单变化作为结束依据。
- 限制：订单接口延迟或记录缺少可解析时间时无法确认结束，界面保留待确认；真机仍需验证服务端记录生成时序。
- 限制：本地终止进程期间无法后台执行 Dart 轮询，只能在下次启动/恢复前台时立即补查。

## 本次变更：refactor-app-motion-and-transitions
- APK 构建（2026-09-09）：全架构与单 ARM64 release 构建曾在 Dart AOT 阶段退出 -9；内存压力较高，使用临时 GRADLE_OPTS 限制 Gradle 堆为 1536 MB、workers=1、关闭并行后，ARM64 release 构建成功。未修改项目构建配置；当前 release 仍使用 debug 签名，版本仍为 2.0.0-beta+1。
- 已处理：并发启动 Flutter 命令曾触发 startup lock，iOS ephemeral `.packages` 清理提示；改为串行执行后 `flutter analyze`、`flutter test` 均通过。
- 已处理：单路由动画无法区分前进与返回；Shell 现在使用 Navigator/Page 详情栈及方向元数据。
- 已处理：支付 SDK 返回成功码但服务端订单仍待支付时会误显示成功；现在必须通过订单状态核验。
- 已处理：接水终态清理活动订单后结果丢失；新增按订单 ID 绑定的 `waterResult`，并隔离旧请求晚到响应。
- 限制：当前环境仅检测到 macOS 与 Chrome，没有 Android/iOS 真机，因此未执行 profile 帧时间、相机、蓝牙和真实支付宝回返验证。
## 2026-09-09 版本检查测试 Mock 响应编码
- 现象：测试中的 `MockClient` 直接以字符串字节构造响应，中文 JSON 在 `http` 解码时触发非法字符错误，误判为网络失败。
- 原因：`StreamedResponse` 的 body 必须是 UTF-8 字节流，不能直接传 `String.codeUnits`。
- 处理：改用 `http.Response.bytes(utf8.encode(...), 200)`，并补充远程清单成功、失败和 semver 回归测试。

## 2026-09-09 develop 合并后 iOS 构建失败
- 现象：`flutter analyze` 报 10 个编译错误，GitHub iOS workflow 无法进入有效的 Xcode 构建阶段。
- 原因：合并远程 2.0 整理与 2.1 重构时，启动快照、运行时依赖、热水详情路由和首页回调保留了不同版本的接口。
- 处理：统一饮水仓库、诊断日志和版本注入，补回热水详情路由与首页回调，并保留热水/饮水轮询和持久化；本地 `flutter build ios --no-codesign --release` 已成功。

## 2026-09-10 启动热水返回 `error_args`
- 现象：账号与设备码正常，点击“启动热水”后立即显示 `error_args`。
- 原因：启动动作在真实控制前新增历史订单基线查询，但 `consume/list_record_by_staffid` 的 `start`、`end` 被传为空字符串；旧版协议要求完整的最近 30 天时间范围。
- 影响：失败发生在历史基线查询阶段，尚未进入设备查询、BLE 握手或创建订单，因此容易被误判为账号或设备码错误。
- 修复：历史查询改传本地时间的最近 30 天范围，格式固定为 `yyyy-MM-dd HH:mm:ss`；增加 endpoint 级安全诊断日志与回归测试。
- 验证：请求捕获测试确认 `start`/`end` 非空且相差 30 天；全量测试和静态分析通过，release APK 构建及 v2 签名校验通过。真实服务端结果仍需安装后由用户验证。

## 2026-09-10 历史订单字段与来源失真
- 住理：真实字段为 `consume_money`、`create_at`、`status`，Flutter 误读为 `money`、`create_time`、`status_text`，导致金额统一回退 `¥0`、时间为空、状态伪装成“已结束”，错误值还会被持久化。
- 798：没有历史查询实现，但进入洗浴详情仍触发住理历史加载并展示共享缓存，可能把住理订单误认为 798 记录。
- U净接水：字段与旧版一致，但只保存本 App 创建并轮询完成的订单，不是账号完整历史。
- U净洗衣：字段与旧版一致，但历史仅存在当前内存；离开下单页或重启会丢失，且没有服务端历史列表实现。
- 处理：修正住理字段；隔离 798；准确标注 U净本机记录；补齐洗衣历史持久化。不猜测未知历史接口。
- 验证：住理真实字段与缺值测试、798 隔离 widget 测试、洗衣 codec/恢复/写入测试均通过；全量 25 项测试通过。

## 2026-09-10 洗衣历史测试存在未使用 import
- 现象：首次 `flutter analyze` 报告 `washer_history_repository_test.dart` 存在一个未使用 import。
- 原因：测试调整为直接使用 `PersistedSnapshot` 后，不再需要单独导入账号模型。
- 处理：删除多余 import，重新运行静态分析。
- 结果：`flutter analyze` 无问题。

## 2026-09-10 距离外启动热水形成永久异常会话
- 现象：设备不在蓝牙范围内时点击启动，页面长期显示订单查询失败或状态待确认；重启仍恢复该状态，停止又因缺少 `isn` 无法完成。
- 根因：代码在 BLE 扫描前即持久化 session；扫描、连接、握手、订单和启动确认的所有异常都被统一视为“可能已经启动”，没有保存启动阶段。重启逻辑又会无条件恢复 session 并启动轮询。
- 关联问题：`_pending` 无条件设置 `running=true`；旧 session 无阶段信息；缺少 `isn` 时只有停止失败，没有安全的本地解除入口；启动指令发送后响应丢失与扫描超时需要采用不同处理。
- 待处理：引入分阶段会话，发送前明确失败自动回滚，发送后不确定保留；为历史异常会话提供带说明的本地解除操作。

## 2026-09-10 首页少量进行中任务被拉伸
- 现象：首页“进行中”只有一个或两个任务时，人物/任务区域没有稳定靠左排列。
- 根因：每项宽度使用 `constraints.maxWidth / tasks.length`，一个任务占整行、两个任务各占半行，布局会随数量拉伸。
- 待处理：使用固定三列宽度并左对齐排列，一个任务占左一列、两个任务占左两列。

## 2026-09-11 当前工作区 APK 构建失败
- 现象：`flutter analyze` 报 4 个 Dart 错误；`flutter build apk --release` 在 `:app:compileFlutterBuildRelease` 的 kernel snapshot 阶段失败。
- 根因：未完成的热水分阶段改动存在可空 `session` 传参、缺失 `_discardSession` 方法，以及未导入 `HotwaterSessionPhase` 三处代码问题。
- 旁支：`bash tools/release/build_android_release.sh --validate-only` 读取根目录 `public/version.json`，与 `pubspec.yaml` 的 2.1.1 不一致；项目实际版本清单为 `assets/public/version.json`。当前也没有 `android/key.properties`，正式签名配置尚未提供。
- 处理：已纳入 OpenSpec change `fix-hotwater-session-recovery-and-android-build`，Dart 编译阻塞、状态迁移、旧 session 清理、回归测试和发布脚本路径均已修复；正式签名配置仍由发布环境提供。

## 2026-09-11 默认 APK 构建缺少 arm 引擎快照
- 现象：`flutter build apk --release` 已进入 Gradle，但在 `:app:compileFlutterBuildRelease` 的 AOT 阶段失败。
- 原因：当前 Flutter 缓存没有 `android-arm-release/darwin-x64/gen_snapshot`，默认多架构构建仍会尝试生成 32 位 ARM 产物；`android-arm64-release` 与 `android-x64-release` 缓存完整。
- 处理：优先使用 `--target-platform android-arm64` 生成实际发布验证所需的单架构 APK；该环境问题不改变 Dart 源码编译结果。
- 验证：`flutter build apk --release --target-platform android-arm64` 成功；产物为本地 debug 签名验证包，正式发布仍需补充 `android/key.properties` 和 keystore。

## 2026-09-14 Flutter 3.44 正式发布目标不包含 32 位 ARM
- 现象：正式发布脚本默认的 split APK/AAB 构建会尝试 `android-arm`，但 Flutter 3.44.4 本机没有 `android-arm-release/darwin-x64/gen_snapshot`，`flutter precache --android` 也不会提供该文件。
- 影响：源码分析、全量测试和签名配置均通过，但默认发布脚本无法生成正式 APK/AAB。
- 处理：发布脚本显式使用当前 SDK 可用的 `android-arm64,android-x64`，同时生成 split APK、通用 `app-release.apk` 和 AAB；32 位 ARM 设备不在本次正式包支持范围内。正式脚本已验证通过。

## 2026-09-14 正式 AAB native library 符号剥离失败
- 现象：arm64/x64 split APK 和通用 APK 构建成功，但 `flutter build appbundle --release` 在 `Release app bundle failed to strip debug symbols from native libraries` 处失败。
- 影响：正式 AAB 尚未生成，当前只能核验 APK，不能宣称完整 Android 发布完成。
- 处理：安装 Android Command-line Tools，并将其置于当前 Android SDK 的 `cmdline-tools/latest`；AAB 中已确认存在 arm64/x64 的 `libapp.so.sym` 与 `libflutter.so.sym`，完整正式发布脚本已通过。
## 2026-09-14 GitHub release target 使用短 SHA 被拒绝
- 现象：创建 `v2.1.2` 时传入短提交号 `b579008`，GitHub API 返回 `Release.target_commitish is invalid`。
- 影响：第一次请求未创建 release，也未上传资产。
- 处理：改用已推送的 `main` 分支作为 release target 重试。
