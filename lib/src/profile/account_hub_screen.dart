import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../runtime/models/account_session.dart';
import '../runtime/shui_home_state.dart';
import '../theme/shui_assets.dart';
import '../theme/shui_motion.dart';
import '../widgets/shui_components.dart';
import '../widgets/shui_header.dart';

class AccountHubScreen extends StatelessWidget {
  const AccountHubScreen({
    required this.state,
    required this.onBack,
    required this.onSelect,
    super.key,
  });

  final ShuiHomeState state;
  final VoidCallback onBack;
  final ValueChanged<AccountKind> onSelect;

  @override
  Widget build(BuildContext context) {
    final entries = [
      (
        kind: AccountKind.zhuli,
        title: '住理生活',
        asset: ShuiAssets.shuiZhuli,
        color: AppColors.primary
      ),
      (
        kind: AccountKind.shower798,
        title: '慧生活798',
        asset: ShuiAssets.shuiHuisheng798,
        color: AppColors.serviceOrange
      ),
      (
        kind: AccountKind.ujing,
        title: 'U净',
        asset: ShuiAssets.shuiU,
        color: AppColors.serviceBlue
      ),
    ];
    final bottomPadding = AppCustomTokens.bottomBarHeight +
        MediaQuery.paddingOf(context).bottom +
        AppCustomTokens.bottomContentExtraPadding;
    return Scaffold(
      body: Column(
        children: [
          TopHeader(title: '账号中心', showBack: true, onBack: onBack),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppCustomTokens.spaceLg,
                AppCustomTokens.spaceLg,
                AppCustomTokens.spaceLg,
                bottomPadding,
              ),
              child: Column(
                children: [
                  for (var index = 0; index < entries.length; index++)
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: AppCustomTokens.spaceMd,
                      ),
                      child: Align(
                        alignment: index.isEven
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        child: _AccountCircleEntry(
                          title: entries[index].title,
                          asset: entries[index].asset,
                          accent: entries[index].color,
                          onTap: () => onSelect(entries[index].kind),
                          key: ValueKey(
                              'account-entry-${entries[index].kind.name}'),
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

class _AccountCircleEntry extends StatelessWidget {
  const _AccountCircleEntry({
    required this.title,
    required this.asset,
    required this.accent,
    required this.onTap,
    super.key,
  });

  final String title;
  final String asset;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: ShuiPressable(
        onTap: onTap,
        soft: true,
        child: SizedBox(
          width: AppCustomTokens.accountEntryWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: AppCustomTokens.accountEntryDiameter,
                height: AppCustomTokens.accountEntryDiameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                  border: Border.all(
                    color:
                        accent.withValues(alpha: AppCustomTokens.alphaBorder),
                    width: AppCustomTokens.strokeThin,
                  ),
                ),
                alignment: Alignment.center,
                child: ExcludeSemantics(
                  child: DecorativeImage(asset,
                      size: AppCustomTokens.accountEntryImageSize),
                ),
              ),
              const SizedBox(height: AppCustomTokens.spaceSm),
              ExcludeSemantics(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTypography.textTheme.titleSmall
                      ?.copyWith(color: AppColors.deepText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
