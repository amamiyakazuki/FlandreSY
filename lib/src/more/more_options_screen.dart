// Design tokens used: AppColors, AppTypography.textTheme, AppCustomTokens space/shell.
// Reference: P_PLAN/...Reference.md §4.10 + legacy ShuiScreens.kt MoreOptionsScreen (2990).

import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../theme/shui_assets.dart';
import '../widgets/more_option_row.dart';
import '../widgets/shui_header.dart';
import '../widgets/shui_overlay_host.dart';
import 'about_dialog.dart';
import 'permission_check.dart';
import 'version_check.dart';

/// 更多选项页（M1）。6 行入口（对齐 legacy MoreOptionsScreen）+ 弹窗（About/版本/占位）。
/// 版本检查/权限/日志/导入导出为 fake（真实功能留 stage4）。
class MoreOptionsScreen extends StatefulWidget {
  const MoreOptionsScreen({
    required this.onBack,
    required this.onImportDevices,
    required this.onExportDevices,
    required this.onOpenLogs,
    this.onLegacyRecovery,
    this.appVersion = kCurrentAppVersion,
    super.key,
  });

  final VoidCallback onBack;

  /// 导入设备：fake 联动（刷新本地设备列表）。
  final VoidCallback onImportDevices;
  final VoidCallback onExportDevices;
  final VoidCallback onOpenLogs;
  final String appVersion;
  final VoidCallback? onLegacyRecovery;

  @override
  State<MoreOptionsScreen> createState() => _MoreOptionsScreenState();
}

enum _Overlay { none, about, version }

class _MoreOptionsScreenState extends State<MoreOptionsScreen> {
  _Overlay _overlay = _Overlay.none;
  VersionCheckResult? _versionResult;
  bool _checkingVersion = false;

  void _dismiss() => setState(() => _overlay = _Overlay.none);

  /// 检查远程版本清单并展示结果。
  Future<void> _checkVersion() async {
    if (_checkingVersion) return;
    setState(() => _checkingVersion = true);
    final result = await checkLatestVersion(currentVersion: widget.appVersion);
    if (!mounted) {
      return;
    }
    setState(() {
      _checkingVersion = false;
      _versionResult = result;
      _overlay = _Overlay.version;
    });
  }

  Future<void> _checkPermissions() async {
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => const PermissionCheckScreen(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final bottomPadding = AppCustomTokens.bottomBarHeight +
        bottomInset +
        AppCustomTokens.bottomContentExtraPadding;
    return PopScope(
      canPop: _overlay == _Overlay.none,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _overlay != _Overlay.none) _dismiss();
      },
      child: Scaffold(
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
            ShuiOverlayHost(
                child: _overlay == _Overlay.none
                    ? null
                    : KeyedSubtree(
                        key: ValueKey(_overlay),
                        child: switch (_overlay) {
                          _Overlay.about => AboutDialogCard(
                              onDismiss: _dismiss,
                              appVersion: widget.appVersion,
                            ),
                          _Overlay.version => VersionCheckDialogCard(
                              result: _versionResult!,
                              onDismiss: _dismiss,
                              onRetry: () {
                                _dismiss();
                                _checkVersion();
                              }),
                          _Overlay.none => const SizedBox.shrink(),
                        })),
          ],
        ),
      ),
    );
  }

  List<_OptionRowData> _rows() {
    return [
      if (widget.onLegacyRecovery != null)
        _OptionRowData(
            icon: ShuiAssets.shuiRed3,
            title: '旧数据保全',
            subtitle: '查看旧记录与登录、核对进度',
            onTap: widget.onLegacyRecovery!),
      _OptionRowData(
        icon: ShuiAssets.shuiRed1,
        title: '权限检测',
        subtitle: '查看权限状态，按需申请或前往设置',
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
        subtitle: _checkingVersion ? '正在检查更新…' : '当前版本 ${widget.appVersion}',
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
