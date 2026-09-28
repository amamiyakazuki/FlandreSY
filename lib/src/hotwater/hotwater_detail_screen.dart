// Design tokens used: AppColors, AppTypography.textTheme, AppCustomTokens space/radius.
// Reference: P_PLAN/...Reference.md §4.9 + legacy ShuiScreens.kt HotwaterDetailScreen (2514).

import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../runtime/fake_shui_runtime.dart';
import '../runtime/hotwater_state.dart';
import '../theme/shui_assets.dart';
import '../theme/shui_motion.dart';
import '../widgets/shui_components.dart';
import '../widgets/shui_header.dart';

/// 热水详情页（H1）。当前热水/洗浴状态 + 大 start/stop 双按钮（按浴室偏好分支）+ 历史列表。
class HotwaterDetailScreen extends StatelessWidget {
  const HotwaterDetailScreen({
    required this.state,
    required this.onBack,
    required this.onStart,
    required this.onStop,
    this.onClearLocal,
    super.key,
  });

  final ShuiHomeState state;
  final VoidCallback onBack;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback? onClearLocal;

  bool get _use798 =>
      state.hotwaterControlSystem == BathSystemPreference.shower798;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    final historyStatus = state.hotwater.historyStatus;
    final historyMessage = historyStatus.message?.trim().isNotEmpty == true
        ? historyStatus.message
        : switch (historyStatus.state) {
            RuntimeTaskState.idle =>
              state.hotwaterHistory.isEmpty ? '热水历史尚未加载' : '历史记录尚未刷新',
            RuntimeTaskState.loading => '正在加载热水历史',
            RuntimeTaskState.failure => '热水历史加载失败，请稍后重试',
            RuntimeTaskState.loginRequired => '请先登录住理账号后查询历史',
            RuntimeTaskState.permissionRequired => '查询热水历史所需权限尚未授予',
            RuntimeTaskState.paymentInProgress => '正在处理热水历史请求',
            RuntimeTaskState.unavailable => '热水历史暂不可用，请稍后重试',
            RuntimeTaskState.success => null,
          };
    final busy = state.hotwaterStart.isBusy || state.hotwaterStop.isBusy;
    final session = state.hotwater.session;
    final canClearLocal = !busy &&
        session != null &&
        session.phase != HotwaterSessionPhase.active &&
        onClearLocal != null;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final bottomPadding = AppCustomTokens.bottomBarHeight +
        bottomInset +
        AppCustomTokens.bottomContentExtraPadding;
    return Scaffold(
      body: Column(
        children: [
          TopHeader(title: '热水详情页', showBack: true, onBack: onBack),
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
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _DetailTitle(
                            icon: ShuiAssets.shuiFire, title: '当前热水'),
                        const SizedBox(height: AppCustomTokens.spaceSm),
                        RuntimeStatusBanner(status: state.hotwaterStart),
                        if (state.hotwaterStop.message != null) ...[
                          const SizedBox(height: AppCustomTokens.spaceXs),
                          RuntimeStatusBanner(status: state.hotwaterStop),
                        ],
                        if (canClearLocal) ...[
                          const SizedBox(height: AppCustomTokens.spaceXs),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: onClearLocal,
                              child: const Text('仅清除本地状态'),
                            ),
                          ),
                        ],
                        const SizedBox(height: AppCustomTokens.spaceSm),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final labels = [
                              _use798 ? '启动洗浴' : '启动热水',
                              _use798 ? '停止洗浴' : '停止热水',
                            ];
                            final available = (constraints.maxWidth -
                                    AppCustomTokens.spaceSm) /
                                2;
                            final fits = labels.every((label) {
                              final painter = TextPainter(
                                text: TextSpan(
                                    text: label, style: textTheme.labelLarge),
                                textDirection: Directionality.of(context),
                                textScaler: MediaQuery.textScalerOf(context),
                              )..layout();
                              final width = painter.width;
                              painter.dispose();
                              return width + 2 * AppCustomTokens.spaceMd + 2 <=
                                  available;
                            });
                            final start = _ControlButton(
                                label: labels[0], onTap: onStart);
                            final stop =
                                _ControlButton(label: labels[1], onTap: onStop);
                            return fits
                                ? Row(children: [
                                    Expanded(child: start),
                                    const SizedBox(
                                        width: AppCustomTokens.spaceSm),
                                    Expanded(child: stop),
                                  ])
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      start,
                                      const SizedBox(
                                          height: AppCustomTokens.spaceSm),
                                      stop,
                                    ],
                                  );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppCustomTokens.spaceSm),
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _DetailTitle(
                          icon: ShuiAssets.shuiReshui,
                          title: _use798 ? '洗浴记录' : '住理热水历史',
                        ),
                        const SizedBox(height: AppCustomTokens.spaceSm),
                        if (!_use798 && historyMessage != null)
                          RuntimeStatusBanner(
                              status: RuntimeActionStatus(
                                  state: historyStatus.state,
                                  message: historyMessage)),
                        if (_use798)
                          Text(
                            '慧生活798暂不提供账号历史，本页不会混入住理订单。',
                            style: textTheme.bodySmall
                                ?.copyWith(color: AppColors.mutedText),
                          )
                        else if (state.hotwaterHistory.isEmpty &&
                            historyStatus.state == RuntimeTaskState.success)
                          Text(
                            '暂无热水历史',
                            style: textTheme.bodySmall
                                ?.copyWith(color: AppColors.mutedText),
                          )
                        else
                          ...state.hotwaterHistory.map(
                            (h) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppCustomTokens.spaceSm,
                              ),
                              child: _HistoryRow(
                                time: h.time,
                                device: '设备 ${h.deviceId}',
                                amount: h.amount,
                                status: h.status,
                              ),
                            ),
                          ),
                      ],
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

class _DetailTitle extends StatelessWidget {
  const _DetailTitle({required this.icon, required this.title});

  final String icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(children: [
        DecorativeImage(icon, size: AppCustomTokens.navIconSize),
        const SizedBox(width: AppCustomTokens.spaceSm),
        Flexible(
          child: Text(title,
              style: AppTypography.textTheme.titleMedium
                  ?.copyWith(color: AppColors.deepText)),
        ),
        const SizedBox(width: AppCustomTokens.spaceSm),
        DecorativeImage(ShuiAssets.shuiThreeStar,
            size: AppCustomTokens.statusIconSize - AppCustomTokens.spaceXs,
            opacity: AppCustomTokens.alphaMuted),
      ]);
}

// Page-local so other screens keep their existing button sizing.
class _ControlButton extends StatelessWidget {
  const _ControlButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ShuiPressable(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(
              minHeight: AppCustomTokens.primaryActionHeight),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(
              horizontal: AppCustomTokens.spaceMd,
              vertical: AppCustomTokens.spaceSm),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [
              AppColors.primaryLight,
              AppColors.primary,
              AppColors.primaryDark,
            ]),
            borderRadius: BorderRadius.circular(AppCustomTokens.radiusLarge),
            border: Border.all(
                color: AppColors.onPrimary
                    .withValues(alpha: AppCustomTokens.alphaMuted),
                width: AppCustomTokens.strokeThin),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: AppTypography.textTheme.labelLarge
                  ?.copyWith(color: AppColors.onPrimary)),
        ),
      );
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.time,
    required this.device,
    required this.amount,
    required this.status,
  });

  final String time;
  final String device;
  final String amount;
  final String status;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppCustomTokens.radiusMedium,
        vertical: AppCustomTokens.spaceSm,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppCustomTokens.radiusMedium),
        border: Border.all(
          color: AppColors.cardBorder
              .withValues(alpha: AppCustomTokens.alphaOverlay),
          width: AppCustomTokens.strokeThin,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            time,
            style: textTheme.bodyMedium?.copyWith(color: AppColors.deepText),
          ),
          const SizedBox(height: AppCustomTokens.spaceXs),
          Text(
            device,
            softWrap: true,
            style: textTheme.bodyMedium?.copyWith(color: AppColors.deepText),
          ),
          const SizedBox(height: AppCustomTokens.spaceSm),
          Wrap(
            spacing: AppCustomTokens.spaceSm,
            runSpacing: AppCustomTokens.spaceXs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                amount,
                style:
                    textTheme.titleSmall?.copyWith(color: AppColors.deepText),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppCustomTokens.spaceSm,
                    vertical: AppCustomTokens.spaceXs),
                decoration: BoxDecoration(
                  color: AppColors.serviceGreen
                      .withValues(alpha: AppCustomTokens.alphaChip),
                  borderRadius:
                      BorderRadius.circular(AppCustomTokens.radiusSmall),
                  border: Border.all(
                      color: AppColors.serviceGreen
                          .withValues(alpha: AppCustomTokens.alphaSoftBorder)),
                ),
                child: Text(status,
                    style: textTheme.labelMedium
                        ?.copyWith(color: AppColors.serviceGreen)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
