# Android 候选构建与稳定清单

C6a 只提供工具，不自动构建正式包或发布。后续 C6b 须先确认候选版本、旧包支持范围与安装验收；再单独批准发布。工具不上传、不调用发布接口，也不修改现有稳定清单。

## 发布前准备

- Python 3、JDK 17、已锁定 Flutter/依赖；Android SDK 的 `aapt`、`apksigner` 在 PATH，或配置 `ANDROID_HOME` / `ANDROID_SDK_ROOT`。
- 原有正式签名的 `android/key.properties`。标准 Java Properties 格式；相对 storeFile 相对 `android/`，绝对路径原样解析。密码/密钥不提交，不作为命令行参数。
- 已确认的升级范围与真实旧 APK。至少包括 2.1.4 通用、ARM64、x64 三种已发布包，其他要支持的旧版本一并纳入。分别从可信发布记录取得 SHA-256；不能用一个随意填写的最高码代替文件核验。
- 更新候选 `pubspec.yaml` 的版本号/构建号后提交候选源码，**不要提前改稳定版 version.json**。构建号必须高于全部所选旧包及已公开扩展清单的构建号；当前仓库仍为 2.1.4+6，本工具应拒绝把它作为新迁移版本。
- 工具要求已跟踪文件无未提交修改、构建输入无未跟踪文件。先处理自己的工作区记录，不由脚本自动清理或暂存用户改动。

将本地基线 JSON 放在仓库之外，结构如下（说明占位不能直接用于构建）：

```json
{
  "schemaVersion": 1,
  "scope": "经用户确认的升级起点与包型",
  "artifacts": [
    {"path": "old/app-release.apk", "sha256": "从可信发布记录取得的64位摘要"},
    {"path": "old/app-arm64-v8a-release.apk", "sha256": "从可信发布记录取得的64位摘要"},
    {"path": "old/app-x86_64-release.apk", "sha256": "从可信发布记录取得的64位摘要"}
  ]
}
```

path 相对该基线文件所在目录。工具逐个读取实际 APK，检查哈希、包名、非调试标志、版本码、ABI 和签名一致性，报告只覆盖提供的升级范围。

## 执行（仅在获准构建时）

```bash
bash tools/release/build_android_release.sh --baseline /absolute/path/baseline.json --validate-only
bash tools/release/build_android_release.sh --baseline /absolute/path/baseline.json
```

第一条仅预检，不能称为新产物验收。第二条先使用锁定依赖、运行分析和全量 Flutter 测试，再构建 ARM64+x64 通用 APK，核验实际输出并写入新的 `build/release-verification/<version-build-unique>/`。报告含源码提交、Flutter/aapt/apksigner 信息、历史基线、APK 元信息、大小和 SHA-256。不会用目录中遗留的专用包作为新产物。

AAB 仅显式请求时额外构建，需可用 bundletool JAR、keytool、jarsigner；单独核验 manifest、架构和签名，不能直接安装：

```bash
bash tools/release/build_android_release.sh --baseline /absolute/path/baseline.json --with-aab --bundletool /absolute/path/bundletool.jar
```

直接 Gradle/Flutter release 也必须配置正式签名，缺失时失败，不回退 Debug。一般本地验证用独立 Debug 包；CI 自动验证缺少正式签名确实被拒绝。

## 发布后的稳定清单准备

正式候选包和覆盖升级通过、用户确认发布后，人工上传并公开该 Release。随后准备 notes.json（`release_date` 字符串、`changelog` 字符串数组）并运行：

```bash
python3 tools/release/prepare_stable_manifest.py --report /absolute/path/verification.json --notes /absolute/path/notes.json
```

它检查本地 APK 未变化，GitHub 对应 tag 已公开且非预发布、资产名称/大小正确，并重新下载公开 APK 计算 SHA-256 与已验证产物比对。失败不输出新的清单。成功只在报告旁生成 `stable-manifest.candidate.json`，不覆盖线上或仓库稳定清单。

在已授权的发布流程中审阅候选清单，将相同内容复制到 `assets/public/version.json` 和 `public/version.json` 后提交/推送。保留旧字段及旧地址供旧客户端使用；新增 schemaVersion=2、Android buildNumber 和 iOS unavailable。不得先推送新稳定清单再等待资产发布。没有 iOS 更新渠道，不提供 APK 兜底。

## 离线测试

```bash
python3 -m unittest discover -s tools/release/tests -v
```

测试以临时文件、Java 假配置、固定工具响应验证失败门禁及完整流程，不访问真实密钥、服务、正式产物或设备。测试通过不替代 C6b 签名候选验证和覆盖安装验收。
