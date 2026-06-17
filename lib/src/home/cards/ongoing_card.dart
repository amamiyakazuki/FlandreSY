// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Design tokens used: AppColors surface/service palette, AppTypography.textTheme, AppCustomTokens spacing/radius/sizing/alpha.

import 'package:flutter/material.dart';

import '../../../design_tokens.dart';
import '../../runtime/fake_shui_runtime.dart';
import '../../theme/shui_assets.dart';
import '../../theme/shui_motion.dart';
import '../../widgets/shui_components.dart';

class OngoingCard extends StatelessWidget {
  const OngoingCard({required this.tasks, super.key});

  final List<HomeTaskUi> tasks;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(icon: ShuiAssets.shuiFire, title: '进行中'),
          const SizedBox(height: AppCustomTokens.spaceSm),
          AnimatedSwitcher(
            duration: ShuiMotion.normal,
            switchInCurve: ShuiMotion.easeOut,
            switchOutCurve: ShuiMotion.easeIn,
            child: tasks.isEmpty
                ? const _EmptyRunningCard()
                : Row(
                    key: ValueKey(tasks.map((task) => task.title).join('|')),
                    children: tasks.take(3).map((task) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppCustomTokens.spaceXs,
                          ),
                          child: RunningStatusCard(task: task),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRunningCard extends StatelessWidget {
  const _EmptyRunningCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('empty-running'),
      width: double.infinity,
      constraints: const BoxConstraints(
        minHeight: AppCustomTokens.runningCardMinHeight,
      ),
      padding: const EdgeInsets.all(AppCustomTokens.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: AppCustomTokens.alphaPanel),
        borderRadius: BorderRadius.circular(AppCustomTokens.radiusMedium),
        border: Border.all(
          color: AppColors.cardBorder
              .withValues(alpha: AppCustomTokens.alphaMuted),
          width: AppCustomTokens.strokeThin,
        ),
      ),
      child: Row(
        children: [
          DecorativeImage(
            ShuiAssets.shuiThreeStar,
            size: AppCustomTokens.statusIconSize,
            opacity: AppCustomTokens.alphaMuted,
          ),
          const SizedBox(width: AppCustomTokens.spaceSm),
          Expanded(
            child: Text(
              '无任务',
              style: AppTypography.textTheme.titleMedium?.copyWith(
                color: AppColors.mutedText,
              ),
            ),
          ),
          DecorativeImage(
            ShuiAssets.shuiCloud,
            size: AppCustomTokens.compactActionHeight,
            opacity: AppCustomTokens.alphaDisabled,
          ),
        ],
      ),
    );
  }
}

class RunningStatusCard extends StatelessWidget {
  const RunningStatusCard({required this.task, super.key});

  final HomeTaskUi task;

  @override
  Widget build(BuildContext context) {
    final color = switch (task.target) {
      HomeTaskTarget.drinking => AppColors.serviceBlue,
      HomeTaskTarget.washer => AppColors.serviceOrange,
      HomeTaskTarget.hotwater => AppColors.primary,
    };
    return Container(
      constraints: const BoxConstraints(
        minHeight: AppCustomTokens.runningCardMinHeight,
      ),
      padding: const EdgeInsets.all(AppCustomTokens.spaceSm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppCustomTokens.alphaVeryLow),
        borderRadius: BorderRadius.circular(AppCustomTokens.radiusMedium),
        border: Border.all(
          color: color.withValues(alpha: AppCustomTokens.alphaSoftBorder),
          width: AppCustomTokens.strokeThin,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecorativeImage(
            ShuiAssets.png(task.asset),
            size: AppCustomTokens.serviceIconSize,
          ),
          const SizedBox(height: AppCustomTokens.spaceXs),
          Text(
            task.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.textTheme.labelMedium?.copyWith(color: color),
          ),
          Text(
            task.extra,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.textTheme.bodySmall?.copyWith(
              color: AppColors.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}
