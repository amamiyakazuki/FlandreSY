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

  bool _busy = false;
  String? _feedback;

  @override
  void initState() {
    super.initState();
    widget.log.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant LogScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.log != widget.log) {
      oldWidget.log.removeListener(_refresh);
      widget.log.addListener(_refresh);
      _logText = widget.log.read();
    }
  }

  @override
  void dispose() {
    widget.log.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() => _logText = widget.log.read());
  }

  Future<void> _clear() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _feedback = '正在清空日志';
    });
    try {
      await widget.log.clear();
      if (mounted) setState(() => _feedback = '日志已清空，后续新事件会继续记录');
    } catch (_) {
      if (mounted) setState(() => _feedback = '清空未完成，请重试');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _logText = widget.log.read();
        });
      }
    }
  }

  Future<void> _retry() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _feedback = null;
    });
    try {
      await widget.log.retryStorage();
      if (mounted) setState(() => _feedback = '诊断存储已恢复');
    } catch (_) {
      if (mounted) setState(() => _feedback = '诊断存储未恢复，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy() async {
    if (_busy) return;
    try {
      await Clipboard.setData(ClipboardData(text: widget.log.read()));
    } catch (_) {
      if (mounted) setState(() => _feedback = '复制未完成，请重试');
      return;
    }
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
                          enabled: !_busy,
                          compact: true,
                          onTap: _refresh,
                        ),
                      ),
                      const SizedBox(width: AppCustomTokens.spaceSm),
                      Expanded(
                        child: PrimaryGradientButton(
                          label: '复制',
                          compact: true,
                          enabled: hasLog && !_busy,
                          onTap: _copy,
                        ),
                      ),
                      const SizedBox(width: AppCustomTokens.spaceSm),
                      Expanded(
                        child: PrimaryGradientButton(
                          label: _busy ? '处理中' : '清空',
                          compact: true,
                          enabled: hasLog && !_busy,
                          onTap: _clear,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppCustomTokens.spaceMd),
                  if (_feedback != null || widget.log.storageError != null)
                    Padding(
                      padding: const EdgeInsets.only(
                          bottom: AppCustomTokens.spaceSm),
                      child: Text(
                          [
                            if (_feedback != null) _feedback!,
                            if (widget.log.storageError != null)
                              widget.log.storageError!
                          ].join('\n'),
                          key: const ValueKey('diagnostic-feedback'),
                          style: textTheme.bodySmall),
                    ),
                  if (widget.log.storageError != null)
                    TextButton(
                        onPressed: _busy ? null : _retry,
                        child: const Text('重试存储')),
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
