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
import 'version_check.dart';

/// 更多选项页（M1）。6 行入口（对齐 legacy MoreOptionsScreen）+ 弹窗（About/版本/占位）。
/// 版本检查/权限/日志/导入导出为 fake（真实功能留 stage4）。
class MoreOptionsScreen extends StatefulWidget {
  const MoreOptionsScreen({
    required this.onBack,
    required this.onImportDevices,
    required this.useSimulatedBackend,
    required this.onToggleSimulatedBackend,
    super.key,
  });

  final VoidCallback onBack;

  /// 导入设备：fake 联动（刷新本地设备列表）。
  final VoidCallback onImportDevices;

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

  /// 检查版本（fake：从打包 asset 读版本清单 → 对比 → 弹窗）。
  Future<void> _checkVersion() async {
    final result = await checkLatestVersionFake();
    if (!mounted) {
      return;
    }
    setState(() {
      _versionResult = result;
      _overlay = _Overlay.version;
    });
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
            AboutDialogCard(onDismiss: _dismiss)
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
        subtitle: '打开系统应用权限设置',
        onTap: () => _showInfo(
          '权限检测',
          '真实权限申请（蓝牙/相机/通知）跳转系统设置将在阶段4接入。',
        ),
      ),
      _OptionRowData(
        icon: ShuiAssets.shuiRed2,
        title: '日志与诊断',
        subtitle: '查看本地运行日志',
        onTap: () => _showInfo(
          '日志与诊断',
          '本地运行日志查看器（导出、过滤等）将在阶段4接入。',
        ),
      ),
      _OptionRowData(
        icon: ShuiAssets.shuiRed3,
        title: '检查版本',
        subtitle: '当前版本 $kCurrentAppVersion',
        onTap: _checkVersion,
      ),
      _OptionRowData(
        icon: ShuiAssets.shuiRed4,
        title: '导出洗衣机设备列表',
        subtitle: '复制本地设备到剪贴板',
        onTap: () => _showInfo(
          '导出设备列表',
          '设备列表已复制（示例）。真实剪贴板导出将在阶段4接入。',
        ),
      ),
      _OptionRowData(
        icon: ShuiAssets.shuiRed5,
        title: '导入洗衣机设备列表',
        subtitle: '从剪贴板恢复本地设备',
        onTap: () {
          widget.onImportDevices();
          _showInfo(
            '导入设备列表',
            '已触发设备列表刷新（示例）。真实剪贴板导入将在阶段4接入。',
          );
        },
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
