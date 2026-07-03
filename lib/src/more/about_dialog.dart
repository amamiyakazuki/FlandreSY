// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Design tokens used: AppColors, AppTypography.textTheme, AppCustomTokens space/sizing.
// Reference: legacy ShuiScreens.kt AboutDialog (3219) + VersionCheckDialog (3079).

import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../theme/shui_assets.dart';
import '../widgets/more_option_row.dart';
import '../widgets/shui_components.dart';
import 'version_check.dart';

/// 关于弹窗（sleep 插图 + 版本 + 支持说明 + 知道啦）。对齐 legacy AboutDialog。
class AboutDialogCard extends StatelessWidget {
  const AboutDialogCard({required this.onDismiss, super.key});

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
            '版本 $kCurrentAppVersion\n'
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
class VersionCheckDialogCard extends StatelessWidget {
  const VersionCheckDialogCard({
    required this.result,
    required this.onDismiss,
    super.key,
  });

  final VersionCheckResult result;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    final title = result.hasUpdate ? '发现新版本' : '已是最新版本';
    final body = result.hasUpdate
        ? '最新版本 ${result.latest.version}（当前 ${result.current}）\n'
            '${result.latest.changelog.join('；')}\n'
            '可前往 GitHub Releases 下载更新。'
        : '当前版本 ${result.current} 已是最新。';
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
          PrimaryGradientButton(
            label: result.hasUpdate ? '知道啦（去下载留后续）' : '知道啦',
            onTap: onDismiss,
          ),
        ],
      ),
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
