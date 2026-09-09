// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Design tokens used: AppColors, AppTypography.textTheme, AppCustomTokens space/shell/radius.
// Reference: legacy LogActivity (运行日志: 看/刷新/清空) + AppLogStore. M-REAL 日志与诊断.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design_tokens.dart';
import '../runtime/diagnostic_log.dart';
import '../widgets/shui_components.dart';
import '../widgets/shui_header.dart';

/// 运行日志页（M-REAL）。对齐 legacy LogActivity：标题 + 副标题 + 刷新/清空/复制 + 滚动日志卡。
/// 日志来源为真实 adapter 埋点写入的 [DiagnosticLog]（main 注入持久化实现）。
class LogScreen extends StatefulWidget {
  const LogScreen({required this.log, required this.onBack, super.key});

  final DiagnosticLog log;
  final VoidCallback onBack;

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  late String _logText = widget.log.read();

  void _refresh() => setState(() => _logText = widget.log.read());

  void _clear() {
    widget.log.clear();
    _refresh();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.log.read()));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('日志已复制到剪贴板')));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final bottomPadding = AppCustomTokens.bottomBarHeight +
        bottomInset +
        AppCustomTokens.bottomContentExtraPadding;
    final hasLog = _logText.trim().isNotEmpty;
    return Scaffold(
      body: Column(
        children: [
          TopHeader(title: '运行日志', showBack: true, onBack: widget.onBack),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppCustomTokens.spaceMd,
                AppCustomTokens.spaceMd,
                AppCustomTokens.spaceMd,
                bottomPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '主界面已隐藏日志，后台组件的结果也会记录在这里',
                    style: textTheme.bodyMedium
                        ?.copyWith(color: AppColors.mutedText),
                  ),
                  const SizedBox(height: AppCustomTokens.spaceMd),
                  Row(
                    children: [
                      Expanded(
                        child: PrimaryGradientButton(
                          label: '刷新',
                          compact: true,
                          onTap: _refresh,
                        ),
                      ),
                      const SizedBox(width: AppCustomTokens.spaceSm),
                      Expanded(
                        child: PrimaryGradientButton(
                          label: '复制',
                          compact: true,
                          enabled: hasLog,
                          onTap: _copy,
                        ),
                      ),
                      const SizedBox(width: AppCustomTokens.spaceSm),
                      Expanded(
                        child: PrimaryGradientButton(
                          label: '清空',
                          compact: true,
                          enabled: hasLog,
                          onTap: _clear,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppCustomTokens.spaceMd),
                  Expanded(
                    child: SectionCard(
                      child: SingleChildScrollView(
                        child: Text(
                          hasLog ? _logText : '暂无日志',
                          style: textTheme.bodySmall?.copyWith(
                            color: hasLog
                                ? AppColors.deepText
                                : AppColors.mutedText,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
