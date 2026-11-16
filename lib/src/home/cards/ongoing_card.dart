// Design tokens used: AppColors surface/service palette, AppTypography.textTheme, AppCustomTokens spacing/radius/sizing/alpha.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../design_tokens.dart';
import '../../runtime/models/washer_order.dart' show formatSeconds;
import '../../runtime/shui_runtime.dart';
import '../../theme/shui_assets.dart';
import '../../theme/shui_motion.dart';
import '../../widgets/shui_components.dart';

int _systemNow() => DateTime.now().millisecondsSinceEpoch;

class OngoingCard extends StatelessWidget {
  const OngoingCard({
    required this.tasks,
    this.onOpenTask,
    this.nowMillis = _systemNow,
    super.key,
  });

  final List<HomeTaskUi> tasks;

  /// 点击任务卡打开对应详情页。
  final ValueChanged<HomeTaskTarget>? onOpenTask;
  final int Function() nowMillis;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(icon: ShuiAssets.shuiFire, title: '进行中'),
          const SizedBox(height: AppCustomTokens.spaceSm),
          SizedBox(
            height: _runningContentHeight(context),
            child: tasks.isEmpty
                ? const _EmptyRunningCard()
                : LayoutBuilder(builder: (context, constraints) {
                    final visible = [
                      for (final target in [
                        HomeTaskTarget.hotwater,
                        HomeTaskTarget.washer,
                        HomeTaskTarget.drinking,
                      ])
                        ...tasks.where((task) => task.target == target).take(1),
                    ];
                    final width =
                        (constraints.maxWidth - 2 * AppCustomTokens.spaceXs) /
                            3;
                    return Row(
                      key: const ValueKey('running-task-row'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < visible.length; i++) ...[
                          if (i > 0)
                            const SizedBox(width: AppCustomTokens.spaceXs),
                          SizedBox(
                            key: ValueKey(visible[i].target),
                            width: width,
                            child: RunningStatusCard(
                              key: ValueKey(
                                  '${visible[i].target.name}-${visible[i].id}'),
                              task: visible[i],
                              nowMillis: nowMillis,
                              onTap: onOpenTask == null
                                  ? null
                                  : () => onOpenTask!(visible[i].target),
                            ),
                          ),
                        ],
                      ],
                    );
                  }),
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

class RunningStatusCard extends StatefulWidget {
  const RunningStatusCard({
    required this.task,
    this.onTap,
    this.nowMillis = _systemNow,
    super.key,
  });

  final HomeTaskUi task;
  final VoidCallback? onTap;
  final int Function() nowMillis;

  @override
  State<RunningStatusCard> createState() => _RunningStatusCardState();
}

class _RunningStatusCardState extends State<RunningStatusCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(RunningStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// 只有带结束时刻的任务（洗衣中）才每秒刷新剩余时间。
  void _syncTicker() {
    if (widget.task.endsAtMillis > 0) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  String get _extra {
    final endsAt = widget.task.endsAtMillis;
    if (endsAt <= 0) return widget.task.extra;
    final remain = ((endsAt - widget.nowMillis()) / 1000).ceil();
    return remain > 0 ? '剩余 ${formatSeconds(remain)}' : '即将完成';
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final card = _buildCard(context, task);
    final onTap = widget.onTap;
    if (onTap == null) return card;
    return Semantics(
      button: true,
      label: '${task.title}，$_extra，点击查看',
      child: ShuiPressable(soft: true, onTap: onTap, child: card),
    );
  }

  Widget _buildCard(BuildContext context, HomeTaskUi task) {
    final color = switch (task.target) {
      HomeTaskTarget.drinking => AppColors.serviceBlue,
      HomeTaskTarget.washer => AppColors.serviceOrange,
      HomeTaskTarget.hotwater => AppColors.primary,
    };
    return ExcludeSemantics(
      excluding: widget.onTap != null,
      child: Container(
        height: _runningContentHeight(context),
        padding: const EdgeInsets.symmetric(
          horizontal: AppCustomTokens.spaceSm,
          vertical: AppCustomTokens.spaceXs,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: AppCustomTokens.alphaVeryLow),
          borderRadius: BorderRadius.circular(AppCustomTokens.radiusMedium),
          border: Border.all(
            color: color.withValues(alpha: AppCustomTokens.alphaSoftBorder),
            width: AppCustomTokens.strokeThin,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RunningTaskIcon(asset: ShuiAssets.png(task.asset)),
            const SizedBox(height: AppCustomTokens.spaceXs),
            Text(
              task.title,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style:
                  AppTypography.textTheme.labelMedium?.copyWith(color: color),
            ),
            Text(
              _extra,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.textTheme.bodySmall?.copyWith(
                color: AppColors.mutedText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// The frame depends only on typography, never on task count or text length.
// Keep the original empty height at normal text size; accommodate larger text
// equally in empty and populated states instead of shrinking accessible text.
double _runningContentHeight(BuildContext context) {
  double lineHeight(TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: '任务', style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final height = painter.height;
    painter.dispose();
    return height;
  }

  return math.max(
    AppCustomTokens.runningCardMinHeight,
    _RunningTaskIcon.size +
        AppCustomTokens.spaceXs +
        lineHeight(AppTypography.textTheme.labelMedium!) +
        lineHeight(AppTypography.textTheme.bodySmall!) +
        2 * AppCustomTokens.spaceXs +
        2 * AppCustomTokens.strokeThin,
  );
}

class _RunningTaskIcon extends StatelessWidget {
  const _RunningTaskIcon({required this.asset});

  final String asset;
  static const double size = 20;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Align(
        alignment: Alignment.centerLeft,
        child: DecorativeImage(
          asset,
          width: size,
          height: size,
        ),
      ),
    );
  }
}
