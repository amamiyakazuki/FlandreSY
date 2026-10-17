// Design tokens used: AppColors, AppTypography.textTheme, AppCustomTokens space/sizing.
// Reference: legacy ShuiScreens.kt AboutDialog (3219) + VersionCheckDialog (3079).

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design_tokens.dart';
import '../theme/shui_assets.dart';
import '../widgets/more_option_row.dart';
import '../widgets/shui_components.dart';
import 'version_check.dart';

/// 关于弹窗（sleep 插图 + 版本 + 支持说明 + 知道啦）。对齐 legacy AboutDialog。
class AboutDialogCard extends StatelessWidget {
  const AboutDialogCard({
    required this.onDismiss,
    this.appVersion = kCurrentAppVersion,
    super.key,
  });

  final VoidCallback onDismiss;
  final String appVersion;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    return ShuiModalCard(
      onDismiss: onDismiss,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: DecorativeImage(
              ShuiAssets.sleep,
              size: AppCustomTokens.dialogImageSize,
            ),
          ),
          const SizedBox(height: AppCustomTokens.spaceSm),
          Text(
            '芙兰水衣',
            textAlign: TextAlign.center,
            style: textTheme.titleLarge?.copyWith(color: AppColors.deepText),
          ),
          const SizedBox(height: AppCustomTokens.spaceSm),
          Text(
            '版本 $appVersion\n'
            '当前支持住理热水、慧生活798洗浴、U净洗衣与饮水流程；洗衣支付暂时只支持支付宝。',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
          ),
          const SizedBox(height: AppCustomTokens.spaceMd),
          PrimaryGradientButton(label: '知道啦', onTap: onDismiss),
        ],
      ),
    );
  }
}

/// 版本检查结果弹窗（有新版 → 下载提示 / 已最新）。对齐 legacy VersionCheckDialog。
class VersionCheckDialogCard extends StatefulWidget {
  const VersionCheckDialogCard(
      {required this.result,
      required this.onDismiss,
      this.onRetry,
      this.openUrl,
      super.key});
  final VersionCheckResult result;
  final VoidCallback onDismiss;
  final VoidCallback? onRetry;
  final Future<bool> Function(Uri)? openUrl;

  @override
  State<VersionCheckDialogCard> createState() => _VersionCheckDialogCardState();
}

class _VersionCheckDialogCardState extends State<VersionCheckDialogCard> {
  bool _opening = false;
  String? _feedback;

  Future<void> _openDownload() async {
    if (_opening) return;
    final result = widget.result;
    final url = result.actionUrl;
    if (url == null) return;
    setState(() {
      _opening = true;
      _feedback = null;
    });
    try {
      if (!isReleaseUrl(url,
          version: result.latest?.version, apk: result.hasUpdate)) {
        throw const FormatException('invalid destination');
      }
      final opened = await (widget.openUrl ??
              (uri) => launchUrl(uri, mode: LaunchMode.externalApplication))(
          Uri.parse(url));
      if (mounted) {
        setState(() => _feedback = opened ? '已打开链接，请在浏览器中继续。' : '无法打开链接，请重试。');
      }
    } catch (_) {
      if (mounted) setState(() => _feedback = '打开链接失败，请重试。');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final latest = result.latest;
    final title = switch (result.state) {
      UpdateState.available => '发现新版本',
      UpdateState.failure => '检查更新失败',
      UpdateState.unknown => '当前版本未知',
      UpdateState.noChannel => '更新渠道',
      UpdateState.reviewRelease => '发布信息',
      _ => '暂无可用更新',
    };
    return ShuiModalCard(
      onDismiss: widget.onDismiss,
      child: SingleChildScrollView(
          child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title,
              textAlign: TextAlign.center,
              style: AppTypography.textTheme.titleMedium),
          const SizedBox(height: AppCustomTokens.spaceSm),
          Text(result.message, textAlign: TextAlign.center),
          if (latest != null) ...[
            const SizedBox(height: AppCustomTokens.spaceSm),
            Text('发布版本 ${latest.version}（当前 ${result.current}）'),
            if (latest.releaseDate.isNotEmpty)
              Text('发布日期：${latest.releaseDate}'),
            for (final change in latest.changelog) Text(change),
          ],
          if (_feedback != null) Text(_feedback!),
          const SizedBox(height: AppCustomTokens.spaceMd),
          if (result.actionUrl != null)
            TextButton(
                onPressed: _opening ? null : _openDownload,
                child: Text(_opening ? '正在打开…' : result.actionLabel!)),
          if (result.failed || result.state == UpdateState.unknown)
            TextButton(
                onPressed: widget.onRetry ?? widget.onDismiss,
                child: const Text('重试')),
          PrimaryGradientButton(label: '知道啦', onTap: widget.onDismiss),
        ],
      )),
    );
  }
}

/// 通用提示弹窗（权限检测/日志/导入导出 占位）。
class InfoDialogCard extends StatelessWidget {
  const InfoDialogCard({
    required this.title,
    required this.body,
    required this.onDismiss,
    super.key,
  });

  final String title;
  final String body;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    return ShuiModalCard(
      onDismiss: onDismiss,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(color: AppColors.deepText),
          ),
          const SizedBox(height: AppCustomTokens.spaceSm),
          Text(
            body,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
          ),
          const SizedBox(height: AppCustomTokens.spaceMd),
          PrimaryGradientButton(label: '知道啦', onTap: onDismiss),
        ],
      ),
    );
  }
}
