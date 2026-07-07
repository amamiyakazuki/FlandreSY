// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Design tokens used: AppColors, AppTypography.textTheme, AppCustomTokens space/shell.
// Reference: P_PLAN/...Reference.md §4.10 + legacy ShuiScreens.kt MoreOptionsScreen (2990).

import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../theme/shui_assets.dart';
import '../widgets/more_option_row.dart';
import '../widgets/shui_header.dart';
import 'about_dialog.dart';
import 'permission_check.dart';
import 'version_check.dart';

/// 更多选项页（M1）。6 行入口（对齐 legacy MoreOptionsScreen）+ 弹窗（About/版本/占位）。
/// M-REAL：权限检测/日志/检查版本/导入导出已翻真（见各行 onTap）。
class MoreOptionsScreen extends StatefulWidget {
  const MoreOptionsScreen({
    required this.onBack,
    required this.onImportDevices,
    required this.onExportDevices,
    required this.onOpenLogs,
    required this.useSimulatedBackend,
    required this.onToggleSimulatedBackend,
    this.appVersion = kCurrentAppVersion,
    super.key,
  });

  final VoidCallback onBack;

  /// 导入设备（M-REAL）：读剪贴板 → runtime 校验/写入/刷新 → shell 侧 snackbar。
  final VoidCallback onImportDevices;

  /// 导出设备（M-REAL）：runtime 设备列表 → 剪贴板 → shell 侧 snackbar。
  final VoidCallback onExportDevices;

  /// 打开运行日志页（M-REAL 日志与诊断）。
  final VoidCallback onOpenLogs;

  /// 真实 App 版本号（M-REAL PackageInfo.version；shell 从 runtime.appVersion 传入）。
  final String appVersion;

  /// 当前「使用模拟后端」开关值（Phase 0）。true = 模拟；false = 真实（默认）。
  final bool useSimulatedBackend;

  /// 切换「使用模拟后端」。持久化 + 提示「重启后生效」（adapter 启动时一次性构造，无法热切）。
  final ValueChanged<bool> onToggleSimulatedBackend;

  @override
  State<MoreOptionsScreen> createState() => _MoreOptionsScreenState();
}

enum _Overlay { none, about, version, info }

class _MoreOptionsScreenState extends State<MoreOptionsScreen> {
  _Overlay _overlay = _Overlay.none;
  VersionCheckResult? _versionResult;
  String _infoTitle = '';
  String _infoBody = '';

  void _showInfo(String title, String body) {
    setState(() {
      _infoTitle = title;
      _infoBody = body;
      _overlay = _Overlay.info;
    });
  }

  void _dismiss() => setState(() => _overlay = _Overlay.none);

  bool _checkingVersion = false;

  /// 检查版本（M-REAL：真网 HTTP 拉远端 version.json → 对比真实版本号 → 弹窗，含失败态）。
  Future<void> _checkVersion() async {
    if (_checkingVersion) {
      return;
    }
    setState(() => _checkingVersion = true);
    final result = await checkLatestVersion(current: widget.appVersion);
    if (!mounted) {
      return;
    }
    setState(() {
      _checkingVersion = false;
      _versionResult = result;
      _overlay = _Overlay.version;
    });
  }

  /// 权限检测（M-REAL：申请相机/蓝牙/定位，永久拒绝兜底跳系统设置）→ 结果进信息弹窗。
  Future<void> _checkPermissions() async {
    final message = await runPermissionCheck();
    if (!mounted) {
      return;
    }
    _showInfo('权限检测', message);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final bottomPadding = AppCustomTokens.bottomBarHeight +
        bottomInset +
        AppCustomTokens.bottomContentExtraPadding;
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              TopHeader(title: '更多选项', showBack: true, onBack: widget.onBack),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    AppCustomTokens.spaceMd,
                    AppCustomTokens.spaceMd,
                    AppCustomTokens.spaceMd,
                    bottomPadding,
                  ),
                  child: Column(
                    children: [
                      MoreOptionRow(
                        iconAsset: ShuiAssets.shuiRed3,
                        title: '使用模拟后端',
                        subtitle: widget.useSimulatedBackend
                            ? '当前：模拟数据（重启后生效）'
                            : '当前：真实后端（重启后生效）',
                        trailing: Switch(
                          value: widget.useSimulatedBackend,
                          onChanged: (value) {
                            widget.onToggleSimulatedBackend(value);
                            _showInfo(
                              '使用模拟后端',
                              value
                                  ? '已切换到模拟后端。重启 App 后生效（将使用 Fake 数据，无需真实账号/设备）。'
                                  : '已切换到真实后端。重启 App 后生效（将连接真实登录/网络/支付/蓝牙）。',
                            );
                          },
                          activeThumbColor: AppColors.onPrimary,
                        ),
                      ),
                      const SizedBox(height: AppCustomTokens.spaceSm),
                      for (final row in _rows()) ...[
                        MoreOptionRow(
                          iconAsset: row.icon,
                          title: row.title,
                          subtitle: row.subtitle,
                          onTap: row.onTap,
                        ),
                        const SizedBox(height: AppCustomTokens.spaceSm),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_overlay == _Overlay.about)
            AboutDialogCard(onDismiss: _dismiss, appVersion: widget.appVersion)
          else if (_overlay == _Overlay.version && _versionResult != null)
            VersionCheckDialogCard(result: _versionResult!, onDismiss: _dismiss)
          else if (_overlay == _Overlay.info)
            InfoDialogCard(
              title: _infoTitle,
              body: _infoBody,
              onDismiss: _dismiss,
            ),
        ],
      ),
    );
  }

  List<_OptionRowData> _rows() {
    return [
      _OptionRowData(
        icon: ShuiAssets.shuiRed1,
        title: '权限检测',
        subtitle: '申请相机/蓝牙/定位权限',
        onTap: _checkPermissions,
      ),
      _OptionRowData(
        icon: ShuiAssets.shuiRed2,
        title: '日志与诊断',
        subtitle: '查看本地运行日志',
        onTap: widget.onOpenLogs,
      ),
      _OptionRowData(
        icon: ShuiAssets.shuiRed3,
        title: '检查版本',
        subtitle: _checkingVersion ? '正在连接版本清单' : '当前版本 ${widget.appVersion}',
        onTap: _checkVersion,
      ),
      _OptionRowData(
        icon: ShuiAssets.shuiRed4,
        title: '导出洗衣机设备列表',
        subtitle: '复制本地设备 JSON 到剪贴板',
        onTap: widget.onExportDevices,
      ),
      _OptionRowData(
        icon: ShuiAssets.shuiRed5,
        title: '导入洗衣机设备列表',
        subtitle: '从剪贴板恢复本地设备 JSON',
        onTap: widget.onImportDevices,
      ),
      _OptionRowData(
        icon: ShuiAssets.shuiRed1,
        title: '关于',
        subtitle: '版本、说明与支持范围',
        onTap: () => setState(() => _overlay = _Overlay.about),
      ),
    ];
  }
}

class _OptionRowData {
  const _OptionRowData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}
