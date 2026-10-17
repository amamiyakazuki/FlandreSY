// Design tokens used: AppColors service palette, AppTypography.textTheme, AppCustomTokens spacing/radius/sizing/alpha.
// Reference: P_PLAN/FlandreSY-Complete-Functions-and-UI-Design-Reference.md §4.2 HomeScreen HotWaterCard.

import 'package:flutter/material.dart';

import '../../../design_tokens.dart';
import '../../runtime/shui_runtime.dart';
import '../../runtime/hotwater_state.dart';
import '../../theme/shui_assets.dart';
import '../../theme/shui_motion.dart';
import '../../widgets/shui_components.dart';
import '../../widgets/shui_painters.dart';

class HotWaterCard extends StatelessWidget {
  const HotWaterCard({
    required this.state,
    required this.onStartHotwater,
    required this.onStopHotwater,
    required this.onSwitchBathSystem,
    required this.onOpenDetail,
    super.key,
  });

  final ShuiHomeState state;
  final VoidCallback onStartHotwater;
  final VoidCallback onStopHotwater;
  final VoidCallback onSwitchBathSystem;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final isShower798 =
        state.hotwaterControlSystem == BathSystemPreference.shower798;
    final unselected = state.hotwaterControlSystem == BathSystemPreference.none;
    final copy = HotwaterStatusCopy.fromState(state);
    final hasWarning = [state.hotwaterStart.state, state.hotwaterStop.state]
        .any((status) => const {
              RuntimeTaskState.failure,
              RuntimeTaskState.loginRequired,
              RuntimeTaskState.permissionRequired,
              RuntimeTaskState.unavailable,
            }.contains(status));
    final busy = state.hotwaterStart.isBusy || state.hotwaterStop.isBusy;
    final phase = state.hotwater.session?.phase;
    final statusColor = hasWarning
        ? AppColors.serviceOrange
        : busy
            ? AppColors.primary
            : phase == HotwaterSessionPhase.uncertain
                ? AppColors.serviceOrange
                : !unselected &&
                        state.hotwaterRunning &&
                        phase == HotwaterSessionPhase.active
                    ? AppColors.serviceGreen
                    : AppColors.primary;

    return SectionCard(
      child: Column(
        children: [
          ShuiPressable(
            soft: true,
            onTap: onOpenDetail,
            child: SectionTitle(
              icon: ShuiAssets.shuiFire,
              title: '热水控制页',
              trailing: '查看详情 ›',
            ),
          ),
          const SizedBox(height: AppCustomTokens.spaceXs),
          LayoutBuilder(builder: (context, constraints) {
            // Reserve enough room for every six-character title, independent
            // of the current state. Decorative art gives way to larger text.
            final titleWidth = _textWidth(
                    context, '正在启动热水', AppTypography.textTheme.titleMedium!) +
                AppCustomTokens.spaceSm;
            final imageSize = (constraints.maxWidth - titleWidth).clamp(
                0.0,
                AppCustomTokens.hotWaterCharacterSize -
                    AppCustomTokens.spaceSm);
            return Row(children: [
              Expanded(
                  child: Column(children: [
                const _CurrentStatusLabel(),
                const SizedBox(height: AppCustomTokens.spaceXs),
                Text(
                  copy.title,
                  key: const ValueKey('hotwater-status-title'),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  softWrap: false,
                  style: AppTypography.textTheme.titleMedium
                      ?.copyWith(color: statusColor),
                ),
                const SizedBox(height: AppCustomTokens.spaceXs),
                ShuiPressable(
                  onTap: onSwitchBathSystem,
                  soft: true,
                  child: StatusPill(
                    text: unselected
                        ? '选择系统'
                        : isShower798
                            ? '慧生活798'
                            : '住理生活',
                    color:
                        isShower798 ? AppColors.serviceBlue : AppColors.primary,
                    filled: true,
                  ),
                ),
              ])),
              if (imageSize > 0)
                ShadowedImage(
                    asset: ShuiAssets.hotWaterCharacter, size: imageSize),
            ]);
          }),
          const SizedBox(height: AppCustomTokens.spaceSm),
          LayoutBuilder(builder: (context, constraints) {
            final startLabel = isShower798 ? '启动洗浴' : '启动热水';
            final stopLabel = isShower798 ? '停止洗浴' : '停止热水';
            final style = AppTypography.textTheme.labelLarge!;
            final needed = _textWidth(context, startLabel, style) +
                2 * AppCustomTokens.spaceMd +
                2;
            final compact =
                MediaQuery.textScalerOf(context).scale(style.fontSize!) *
                        (style.height ?? 1.4) <=
                    AppCustomTokens.compactActionHeight;
            final start = PrimaryGradientButton(
                label: startLabel, compact: compact, onTap: onStartHotwater);
            final stop = PrimaryGradientButton(
                label: stopLabel, compact: compact, onTap: onStopHotwater);
            return needed * 2 + AppCustomTokens.spaceSm <= constraints.maxWidth
                ? Row(children: [
                    Expanded(child: start),
                    const SizedBox(width: AppCustomTokens.spaceSm),
                    Expanded(child: stop)
                  ])
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                        start,
                        const SizedBox(height: AppCustomTokens.spaceSm),
                        stop
                      ]);
          }),
          const SizedBox(height: AppCustomTokens.spaceXs),
          LayoutBuilder(builder: (context, constraints) {
            final style = AppTypography.textTheme.bodySmall!;
            final hint = _textWidth(context, copy.hint, style) <=
                    constraints.maxWidth - 32
                ? copy.hint
                : '轻触查看说明';
            return Semantics(
              button: true,
              label: '热水状态说明，点击查看完整内容',
              child: InkWell(
                key: const ValueKey('hotwater-status-details'),
                onTap: () => _showStatusDetails(context, copy),
                borderRadius:
                    BorderRadius.circular(AppCustomTokens.radiusMedium),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 40),
                  child: Row(children: [
                    Expanded(
                        child: Text(
                      hint,
                      key: const ValueKey('hotwater-status-note'),
                      maxLines: 1,
                      softWrap: false,
                      style: style.copyWith(
                          color: hasWarning ||
                                  phase == HotwaterSessionPhase.uncertain
                              ? AppColors.serviceOrange
                              : AppColors.mutedText),
                    )),
                    const Icon(Icons.chevron_right,
                        size: 20, color: AppColors.mutedText),
                  ]),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showStatusDetails(BuildContext context, HotwaterStatusCopy copy) {
    final start = state.hotwaterStart.message?.trim();
    final stop = state.hotwaterStop.message?.trim();
    showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(copy.title),
              content: SingleChildScrollView(
                  child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(copy.hint),
                  if (start != null && start.isNotEmpty) ...[
                    const SizedBox(height: AppCustomTokens.spaceMd),
                    const Text('启动状态'),
                    SelectableText(start),
                  ],
                  if (stop != null && stop.isNotEmpty) ...[
                    const SizedBox(height: AppCustomTokens.spaceMd),
                    const Text('停止状态'),
                    SelectableText(stop),
                  ],
                ],
              )),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('知道了'))
              ],
            ));
  }

  static double _textWidth(BuildContext context, String text, TextStyle style) {
    final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context))
      ..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }
}

class _CurrentStatusLabel extends StatelessWidget {
  const _CurrentStatusLabel();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: DashedRule()),
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: AppCustomTokens.spaceSm),
          child: Text(
            '当前状态',
            style: AppTypography.textTheme.bodyMedium?.copyWith(
              color: AppColors.deepText,
            ),
          ),
        ),
        const Expanded(child: DashedRule()),
      ],
    );
  }
}

/// Presentation-only summaries. Full runtime messages remain available in the
/// details dialog; no control result is inferred from free-form message text.
class HotwaterStatusCopy {
  const HotwaterStatusCopy(this.title, this.hint);
  final String title;
  final String hint;

  factory HotwaterStatusCopy.fromState(ShuiHomeState state) {
    final system = state.hotwaterControlSystem;
    if (system == BathSystemPreference.none) {
      return const HotwaterStatusCopy('尚未选择系统', '请先选择洗浴系统');
    }
    for (final action in [state.hotwaterStop, state.hotwaterStart]) {
      switch (action.state) {
        case RuntimeTaskState.loginRequired:
          return const HotwaterStatusCopy('需要重新登录', '请先登录 · 查看详情');
        case RuntimeTaskState.permissionRequired:
          return const HotwaterStatusCopy('需要授予权限', '请检查权限 · 查看详情');
        case RuntimeTaskState.failure:
          if (state.hotwater.session?.phase == HotwaterSessionPhase.uncertain) {
            return const HotwaterStatusCopy('设备结果待定', '请核对设备 · 查看详情');
          }
          return const HotwaterStatusCopy('本次操作失败', '操作未完成 · 查看详情');
        case RuntimeTaskState.unavailable:
          return const HotwaterStatusCopy('暂时无法操作', '当前不可用 · 查看详情');
        default:
          break;
      }
    }
    if (state.hotwaterStop.isBusy) {
      return const HotwaterStatusCopy('正在处理停止', '请稍候，避免重复点击');
    }
    if (state.hotwaterStart.isBusy) {
      return HotwaterStatusCopy(
          system == BathSystemPreference.shower798 ? '正在启动洗浴' : '正在启动热水',
          '请稍候，避免重复点击');
    }
    switch (state.hotwater.session?.phase) {
      case HotwaterSessionPhase.uncertain:
        return const HotwaterStatusCopy('设备结果待定', '请核对设备 · 查看详情');
      case HotwaterSessionPhase.preparing:
        return const HotwaterStatusCopy('正在准备热水', '请稍候，避免重复点击');
      case HotwaterSessionPhase.starting:
        return const HotwaterStatusCopy('正在确认启动', '请稍候，避免重复点击');
      case HotwaterSessionPhase.active:
        if (state.hotwaterRunning) {
          return system == BathSystemPreference.shower798
              ? const HotwaterStatusCopy('启动请求确认', '请核对设备实际状态')
              : const HotwaterStatusCopy('热水正在使用', '使用完毕请手动关闭');
        }
      case null:
        break;
    }
    return const HotwaterStatusCopy('热水等待启动', '操作前请核对所选设备');
  }
}
