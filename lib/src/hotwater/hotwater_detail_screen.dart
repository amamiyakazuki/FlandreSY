// Design tokens used: AppColors, AppTypography.textTheme, AppCustomTokens space/radius.
// Reference: P_PLAN/...Reference.md §4.9 + legacy ShuiScreens.kt HotwaterDetailScreen (2514).

import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../runtime/fake_shui_runtime.dart';
import '../theme/shui_assets.dart';
import '../widgets/shui_components.dart';
import '../widgets/shui_header.dart';

/// 热水详情页（H1）。当前热水/洗浴状态 + 大 start/stop 双按钮（按浴室偏好分支）+ 历史列表。
class HotwaterDetailScreen extends StatelessWidget {
  const HotwaterDetailScreen({
    required this.state,
    required this.onBack,
    required this.onStart,
    required this.onStop,
    super.key,
  });

  final ShuiHomeState state;
  final VoidCallback onBack;
  final VoidCallback onStart;
  final VoidCallback onStop;

  bool get _use798 =>
      state.hotwaterControlSystem == BathSystemPreference.shower798;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    final busy = state.hotwaterStart.isBusy || state.hotwaterStop.isBusy;
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
                        SectionTitle(icon: ShuiAssets.shuiFire, title: '当前热水'),
                        const SizedBox(height: AppCustomTokens.spaceSm),
                        RuntimeStatusBanner(status: state.hotwaterStart),
                        if (state.hotwaterStop.message != null) ...[
                          const SizedBox(height: AppCustomTokens.spaceXs),
                          RuntimeStatusBanner(status: state.hotwaterStop),
                        ],
                        const SizedBox(height: AppCustomTokens.spaceSm),
                        Row(
                          children: [
                            Expanded(
                              child: PrimaryGradientButton(
                                label: busy
                                    ? '正在处理中'
                                    : (_use798 ? '启动洗浴' : '启动热水'),
                                enabled: !busy &&
                                    state.hotwaterControlSystem !=
                                        BathSystemPreference.none &&
                                    !state.hotwaterRunning,
                                onTap: onStart,
                              ),
                            ),
                            const SizedBox(width: AppCustomTokens.spaceSm),
                            Expanded(
                              child: PrimaryGradientButton(
                                label: busy
                                    ? '正在处理中'
                                    : (_use798 ? '停止洗浴' : '停止热水'),
                                enabled:
                                    !busy && state.hotwater.session != null,
                                onTap: onStop,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppCustomTokens.spaceSm),
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SectionTitle(
                            icon: ShuiAssets.shuiReshui, title: '热水历史'),
                        const SizedBox(height: AppCustomTokens.spaceSm),
                        if (state.hotwaterHistory.isEmpty)
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
      child: Row(
        children: [
          Text(
            time,
            style: textTheme.bodyMedium?.copyWith(color: AppColors.deepText),
          ),
          const SizedBox(width: AppCustomTokens.spaceMd),
          Expanded(
            child: Text(
              device,
              // P2：设备名允许两行不裁。
              maxLines: 2,
              softWrap: true,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(color: AppColors.deepText),
            ),
          ),
          Text(
            amount,
            style: textTheme.titleSmall?.copyWith(color: AppColors.deepText),
          ),
          const SizedBox(width: AppCustomTokens.spaceSm),
          StatusPill(text: status, color: AppColors.serviceGreen, filled: true),
        ],
      ),
    );
  }
}
