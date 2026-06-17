// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Design tokens used: AppColors shell palette, AppTypography.textTheme, AppCustomTokens top/bottom/header/icon spacing.

import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../home/home_screen.dart';
import '../runtime/fake_shui_runtime.dart';
import '../theme/shui_assets.dart';
import '../theme/shui_motion.dart';
import '../widgets/shui_components.dart';
import '../widgets/shui_header.dart';
import '../widgets/shui_painters.dart';

enum MainTab {
  home('功能', 'home'),
  orders('订单', 'orders'),
  devices('设备', 'washer'),
  profile('我的', 'profile');

  const MainTab(this.label, this.iconName);

  final String label;
  final String iconName;
}

class ShuiShell extends StatefulWidget {
  const ShuiShell({super.key});

  @override
  State<ShuiShell> createState() => _ShuiShellState();
}

class _ShuiShellState extends State<ShuiShell> {
  MainTab selectedTab = MainTab.home;
  bool openingVisible = true;
  bool permissionVisible = true;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(ShuiMotion.opening, () {
      if (mounted) {
        setState(() => openingVisible = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final runtime = ShuiRuntimeScope.of(context);
    return AnimatedBuilder(
      animation: runtime,
      builder: (context, _) {
        return AdaptivePhoneContainer(
          child: Stack(
            children: [
              AnimatedSwitcher(
                duration: ShuiMotion.route,
                switchInCurve: ShuiMotion.easeOut,
                switchOutCurve: ShuiMotion.easeIn,
                transitionBuilder: (child, animation) {
                  final offset = Tween<Offset>(
                    begin: const Offset(0.08, 0),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: offset, child: child),
                  );
                },
                child: _tabBody(runtime),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: WavyBottomBar(
                  selectedTab: selectedTab,
                  onTabSelected: (tab) => setState(() => selectedTab = tab),
                ),
              ),
              AnimatedSwitcher(
                duration: ShuiMotion.normal,
                child: openingVisible
                    ? const OpeningMotionOverlay()
                    : const SizedBox.shrink(),
              ),
              AnimatedSwitcher(
                duration: ShuiMotion.normal,
                child: permissionVisible && !openingVisible
                    ? FirstLaunchPermissionDialog(
                        onConfirm: () =>
                            setState(() => permissionVisible = false),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tabBody(FakeShuiRuntime runtime) {
    return KeyedSubtree(
      key: ValueKey(selectedTab),
      child: switch (selectedTab) {
        MainTab.home => HomeScreen(
            state: runtime.state,
            onOpenProfile: () => setState(() => selectedTab = MainTab.profile),
            onOpenDevices: () => setState(() => selectedTab = MainTab.devices),
            onToggleHotwater: runtime.toggleHotwater,
            onScan: runtime.simulateScan,
            onWasherSummary: runtime.openWasherSummary,
            onSwitchBathSystem: runtime.switchBathSystem,
          ),
        MainTab.orders => const PlaceholderPage(
            title: '历史订单',
            body: 'Orders 聚合页将在后续 bounded module 中完整实现。',
          ),
        MainTab.devices => const PlaceholderPage(
            title: '选择设备',
            body: 'Devices 本地设备、预置海七列表和 CRUD 将在后续 bounded module 中实现。',
            showAdd: true,
          ),
        MainTab.profile => const PlaceholderPage(
            title: '我的',
            body: 'Profile 账号向导、住理/U净/798 登录和更多选项将在后续 bounded module 中实现。',
            showSettings: true,
          ),
      },
    );
  }
}

class WavyBottomBar extends StatelessWidget {
  const WavyBottomBar({
    required this.selectedTab,
    required this.onTabSelected,
    super.key,
  });

  final MainTab selectedTab;
  final ValueChanged<MainTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return SizedBox(
      height: AppCustomTokens.bottomBarHeight + bottomInset,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: bottomInset,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryLight,
                    AppColors.primary,
                    AppColors.primaryDark,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: AppCustomTokens.bottomBarHeight,
            child: CustomPaint(
              painter: const _BottomBarPainter(),
              child: Stack(
                children: [
                  Positioned(
                    right: AppCustomTokens.bottomBarReservedHeight,
                    top: AppCustomTokens.spaceSm,
                    child: DecorativeImage(
                      ShuiAssets.shuiBianfu,
                      size: AppCustomTokens.compactActionHeight,
                      opacity: AppCustomTokens.alphaDisabled,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: AppCustomTokens.spaceLg,
                      right: AppCustomTokens.spaceLg,
                      top: AppCustomTokens.spaceSm,
                      bottom: AppCustomTokens.spaceXs,
                    ),
                    child: Row(
                      children: MainTab.values.map((tab) {
                        final selected = tab == selectedTab;
                        return Expanded(
                          child: ShuiPressable(
                            soft: true,
                            onTap: () => onTabSelected(tab),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ShuiLineIcon(
                                  name: tab.iconName,
                                  color: AppColors.onPrimary.withValues(
                                    alpha: selected
                                        ? 1
                                        : AppCustomTokens.alphaDisabled,
                                  ),
                                ),
                                Text(
                                  tab.label,
                                  style: AppTypography.textTheme.labelSmall
                                      ?.copyWith(
                                    color: AppColors.onPrimary.withValues(
                                      alpha: selected
                                          ? 1
                                          : AppCustomTokens.alphaMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
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

class _BottomBarPainter extends CustomPainter {
  const _BottomBarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(0, AppCustomTokens.bottomBarWaveTop);
    var x = 0.0;
    final wave = size.width / 18;
    while (x + wave < size.width) {
      path.quadraticBezierTo(
        x + wave / 2,
        0,
        x + wave,
        AppCustomTokens.bottomBarWaveTop,
      );
      x += wave;
    }
    path
      ..lineTo(size.width, AppCustomTokens.bottomBarWaveTop)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    const gradient = LinearGradient(
      colors: [
        AppColors.primaryLight,
        AppColors.primary,
        AppColors.primaryDark,
      ],
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = gradient.createShader(Offset.zero & size)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class OpeningMotionOverlay extends StatelessWidget {
  const OpeningMotionOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.92, end: 1),
          duration: ShuiMotion.opening,
          curve: ShuiMotion.easeOut,
          builder: (context, scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecorativeImage(
                ShuiAssets.homeTopCharacter,
                size: AppCustomTokens.headerCharacterSize,
              ),
              const SizedBox(height: AppCustomTokens.spaceSm),
              Text(
                '芙兰水衣',
                style: AppTypography.textTheme.displayLarge?.copyWith(
                  color: AppColors.primary,
                ),
              ),
              Text(
                '水、衣、热水，轻轻开始',
                style: AppTypography.textTheme.labelMedium?.copyWith(
                  color: AppColors.mutedText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FirstLaunchPermissionDialog extends StatelessWidget {
  const FirstLaunchPermissionDialog({required this.onConfirm, super.key});

  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.scrim.withValues(alpha: AppCustomTokens.alphaOverlay),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppCustomTokens.spaceXl,
          ),
          child: SectionCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DecorativeImage(
                  ShuiAssets.sleep,
                  size: AppCustomTokens.dialogImageSize,
                ),
                const SizedBox(height: AppCustomTokens.spaceSm),
                Text(
                  '先给小助手一点权限吧',
                  textAlign: TextAlign.center,
                  style: AppTypography.textTheme.titleLarge?.copyWith(
                    color: AppColors.deepText,
                  ),
                ),
                const SizedBox(height: AppCustomTokens.spaceSm),
                Text(
                  '扫码、热水蓝牙、状态通知都需要系统权限。点一下我就会一次性申请，之后就不用反复打扰你啦。',
                  textAlign: TextAlign.center,
                  style: AppTypography.textTheme.bodyMedium?.copyWith(
                    color: AppColors.mutedText,
                  ),
                ),
                const SizedBox(height: AppCustomTokens.spaceMd),
                PrimaryGradientButton(label: '好，开启权限', onTap: onConfirm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    required this.title,
    required this.body,
    this.showSettings = false,
    this.showAdd = false,
    super.key,
  });

  final String title;
  final String body;
  final bool showSettings;
  final bool showAdd;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TopHeader(title: title, showSettings: showSettings, showAdd: showAdd),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppCustomTokens.spaceMd,
                AppCustomTokens.spaceMd,
                AppCustomTokens.spaceMd,
                AppCustomTokens.bottomBarReservedHeight,
              ),
              child: SectionCard(
                child: Center(
                  child: Text(
                    body,
                    textAlign: TextAlign.center,
                    style: AppTypography.textTheme.bodyLarge?.copyWith(
                      color: AppColors.mutedText,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
