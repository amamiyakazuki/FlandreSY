// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
import 'package:flutter/material.dart';

/// FlandreSY 设计令牌 - 基于 Material 3 + 原生视觉精确提取
/// 目标：最大化还原原 Android Compose 界面的视觉效果
///
/// 使用方式：
/// ThemeData(
///   useMaterial3: true,
///   colorScheme: AppColors.colorScheme,
///   textTheme: AppTypography.textTheme,
///   // 其他配置...
/// )
///
/// 然后在 Widget 中使用 AppColors.xxx 或 Theme.of(context).colorScheme

class AppColors {
  // ========== 核心品牌色 (从原生 zhuli_ 颜色 + Compose ShuiColors 提取) ==========
  static const Color primary = Color(0xFFEF4056); // 主红 #EF4056 (更接近 Compose)
  static const Color primaryDark = Color(0xFFD92F4A); // 深红
  static const Color primaryLight = Color(0xFFFF7B8A); // 浅红
  static const Color onPrimary = Color(0xFFFFFFFF);

  static const Color primaryContainer = Color(0xFFFFD9DD);
  static const Color onPrimaryContainer = Color(0xFF5D1019);

  // 次要色 (原生用作 secondary，但 Compose 中 Blue 作为 secondary)
  static const Color secondary = Color(0xFF4D8DEB); // 蓝色 (用于某些服务)
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFE5F0FF); // 推测扩展
  static const Color onSecondaryContainer = Color(0xFF0D3A6B);

  // 第三色 (原生 tertiary)
  static const Color tertiary = Color(0xFF6E5B4E);
  static const Color onTertiary = Color(0xFFFFFFFF);

  // 背景与表面 (极致还原原生浅粉/米白调)
  static const Color background = Color(
    0xFFFFF7F6,
  ); // 原生 zhuli_background + Compose 调整
  static const Color surface = Color(0xFFFFFDFC); // 原生 surface
  static const Color surfaceVariant = Color(0xFFF7E5E6); // 原生 surface_variant
  static const Color onSurface = Color(0xFF281718); // 深色文字
  static const Color onSurfaceVariant = Color(0xFF665153);

  // 强调粉色系 (原生大量使用的软粉，用于卡片、边框、装饰)
  static const Color cardBorder = Color(0xFFFFC6CE); // CardBorder
  static const Color weakPink = Color(0xFFFFE8EC); // WeakPink
  static const Color softPink = Color(0xFFFFF1F3); // SoftPink
  static const Color outline = Color(0xFFD6B8BB); // 原生 outline

  // 文字层级
  static const Color deepText = Color(0xFF4A1D25); // DeepText (标题/重要文字)
  static const Color mutedText = Color(0xFF8D6F75); // MutedText (次要文字)
  static const Color scrim = Color(0xFF000000);

  // 服务专用强调色 (多服务主题还原)
  static const Color serviceBlue = Color(0xFF4D8DEB);
  static const Color serviceOrange = Color(0xFFFFA93A);
  static const Color serviceGreen = Color(0xFF7DBF4C);
  static const Color serviceBrown = Color(0xFF7C4A50);
  static const Color serviceViolet = Color(0xFF8D62E8); // 洗衣套餐第 4 色 (legacy OptionCard)
  static const Color error = Color(0xFFBA1A1A);

  // Material 3 完整 ColorScheme (Light only，无暗黑模式)
  static const ColorScheme colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: primaryContainer,
    onPrimaryContainer: onPrimaryContainer,
    secondary: secondary,
    onSecondary: onSecondary,
    secondaryContainer: secondaryContainer,
    onSecondaryContainer: onSecondaryContainer,
    tertiary: tertiary,
    onTertiary: onTertiary,
    error: error,
    onError: onPrimary,
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    surface: surface,
    onSurface: onSurface,
    surfaceContainerHighest: surfaceVariant,
    onSurfaceVariant: onSurfaceVariant,
    outline: outline,
    outlineVariant: Color(0xFFE8D5D7),
    shadow: scrim,
    scrim: scrim,
    inverseSurface: Color(0xFF3F2A2C),
    onInverseSurface: Color(0xFFFDF0F0),
    inversePrimary: Color(0xFFFFB3B9),
    surfaceTint: primary,
  );
}

class AppTypography {
  // 自定义字体：未来圆 SC (原生 future_round_sc_regular)
  // 使用前请在 pubspec.yaml 中声明：
  // fonts:
  //   - family: FutureRoundSC
  //     fonts:
  //       - asset: assets/fonts/future_round_sc_regular.ttf
  static const String fontFamily = 'FutureRoundSC';

  static final TextTheme textTheme = Typography.material2021().black.copyWith(
        // M3 推荐的显示/标题层级 (加粗 + 自定义字体)
        displayLarge: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.bold,
          fontSize: 34,
          height: 1.2,
        ),
        displayMedium: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.bold,
          fontSize: 28,
          height: 1.2,
        ),
        headlineLarge: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.bold,
          fontSize: 28,
          height: 1.3,
        ),
        headlineMedium: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.bold,
          fontSize: 23,
          height: 1.3,
        ),
        headlineSmall: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.bold,
          fontSize: 20,
          height: 1.3,
        ),
        titleLarge: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.bold,
          fontSize: 20,
          height: 1.3,
        ),
        titleMedium: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.bold,
          fontSize: 17,
          height: 1.4,
        ),
        titleSmall: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 15,
          height: 1.4,
        ),
        bodyLarge: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.normal,
          fontSize: 16,
          height: 1.5,
        ),
        bodyMedium: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.normal,
          fontSize: 14,
          height: 1.5,
        ),
        bodySmall: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.normal,
          fontSize: 12,
          height: 1.5,
        ),
        labelLarge: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.bold,
          fontSize: 15,
          height: 1.4,
        ),
        labelMedium: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.bold,
          fontSize: 13,
          height: 1.4,
        ),
        labelSmall: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 11,
          height: 1.4,
        ),
      );
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: AppColors.colorScheme,
      textTheme: AppTypography.textTheme,
      fontFamily: AppTypography.fontFamily,

      // 按钮样式 (对应原生 18dp 圆角 + 无大写)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppCustomTokens.radiusLarge),
          ),
          textStyle: AppTypography.textTheme.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppCustomTokens.radiusLarge),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppCustomTokens.radiusLarge),
          ),
        ),
      ),

      // Card 样式 (还原软粉背景 + 边框感)
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppCustomTokens.radiusMedium),
          side: const BorderSide(
            color: AppColors.cardBorder,
            width: AppCustomTokens.strokeThin,
          ),
        ),
      ),

      // 输入框等其他 M3 组件可按需扩展
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(AppCustomTokens.radiusMedium),
          ),
        ),
      ),
    );
  }
}

/// 额外自定义令牌 (用于角色图容器、特殊装饰等，保证还原)
class AppCustomTokens {
  // 软粉卡片背景变体 (WeakPink / SoftPink)
  static const Color weakPinkBackground = Color(0xFFFFE8EC);
  static const Color softPinkBackground = Color(0xFFFFF1F3);

  // 常见圆角 (从原生 18dp 按钮推导)
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 18.0;
  static const double radiusExtraLarge = 24.0;

  // 常用间距 (可根据实际测量继续补充)
  static const double spaceXs = 4.0;
  static const double spaceSm = 8.0;
  static const double spaceMd = 16.0;
  static const double spaceLg = 24.0;
  static const double spaceXl = 32.0;

  // 线条、透明度与按压动效
  static const double strokeThin = 1.0;
  static const double strokeMedium = 1.4;
  static const double alphaPressed = 0.88;
  static const double alphaVeryLow = 0.10;
  static const double alphaLow = 0.12;
  static const double alphaChip = 0.13;
  static const double alphaSubtle = 0.16;
  static const double alphaBorder = 0.18;
  static const double alphaLine = 0.20;
  static const double alphaSoftBorder = 0.25;
  static const double alphaAccent = 0.28;
  static const double alphaShadow = 0.35;
  static const double alphaPopup = 0.42;
  static const double alphaMuted = 0.58;
  static const double alphaCard = 0.72;
  static const double alphaCardAlt = 0.75;
  static const double alphaPanel = 0.78;
  static const double alphaStrong = 0.82;
  static const double alphaEmphasis = 0.85;
  static const double alphaHigh = 0.86;
  static const double alphaNearOpaque = 0.90;
  static const double alphaDisabled = 0.46;
  static const double alphaOverlay = 0.46;
  static const double pressScale = 0.97;
  static const double softPressScale = 0.985;

  // Flutter Shell/Home 还原尺寸
  static const double adaptivePhoneMaxWidth = 430.0;
  static const double goldenPhoneHeight = 932.0;
  static const double topHeaderHeight = 118.0;
  static const double topHeaderTallHeight = 132.0;
  static const double topHeaderContentHeight = 108.0;
  static const double headerWaveHeight = 22.0;
  static const double bottomBarHeight = 68.0;
  static const double bottomBarWaveTop = 12.0;
  static const double navIconSize = 25.0;
  static const double navIconSizeLarge = 28.0;
  static const double headerCharacterSize = 116.0;
  static const double headerCharacterSizeSmall = 96.0;
  static const double headerTitleSize = 28.0;
  static const double headerActionIconSize = 32.0;
  static const double hotWaterCharacterSize = 108.0;
  static const double hotWaterCharacterSizeLarge = 116.0;
  static const double scanPanelHeight = 104.0;
  static const double scanImageSize = 84.0;
  static const double scanImageSizeLarge = 92.0;
  static const double scanCircleSize = 96.0;
  static const double scanCircleSizeLarge = 104.0;
  static const double scanCharacterSize = 78.0;
  static const double scanCharacterHeroSize = 104.0;
  static const double scanCharacterHeroSizeLarge = 112.0;
  static const double scanBatSize = 50.0;
  static const double scanBatStartOffset = 92.0;
  static const double washerCharacterSize = 112.0;
  static const double washerCharacterSizeLarge = 118.0;
  static const double serviceIconSize = 28.0;
  static const double serviceIconBoxSize = 34.0;
  static const double statusIconSize = 34.0;
  static const double dialogImageSize = 108.0;
  static const double bottomBarReservedHeight = 96.0;
  static const double bottomContentExtraPadding = 28.0;
  static const double compactActionHeight = 42.0;
  static const double primaryActionHeight = 46.0;
  static const double runningCardMinHeight = 76.0;
  static const double homeLargeNumberSize = 32.0;
  static const double sectionGap = 6.0;

  // ========== Module B1 - Devices 模块还原尺寸 ==========
  // 命名与取值严格对照 legacy ShuiScreens.kt / ShuiComponents.kt 的 dp 值，
  // 集中在此处保持「单一事实来源」，禁止散落到组件内的魔法数字。
  static const double spaceContent =
      18.0; // legacy SectionCard contentPadding 18dp（设备/饮水页大量使用）
  static const double radiusCompact =
      10.0; // legacy RefreshBar / Popup / preset 卡 RoundedCornerShape 10dp
  static const double deviceListIconSize =
      58.0; // legacy DeviceListItem 设备图标 58dp
  static const double deviceActionDotSize =
      18.0; // legacy DeviceListItem 右下操作圆点 18dp
  static const double deviceActionDotStroke = 1.2; // legacy 操作圆点描边 1.2dp
  static const double deviceListLineGap = 5.0; // legacy 列表项三行文字间距 5dp
  static const double presetCellHeight = 58.0; // legacy 海七预设格子高度 58dp
  static const double presetGridHeight = 360.0; // legacy 预设网格滚动区高度 360dp
  static const double emptyBoxSize = 160.0; // legacy empty_box 空状态插画 160dp
  static const double emptyStateHeight = 330.0; // legacy 空状态容器高度 330dp
  static const double devicePopupWidth =
      150.0; // legacy DeviceActionPopup 宽度 150dp
  static const double devicePopupEndPadding = 42.0; // legacy popup 右边距 42dp
  static const double dialogMarginWide =
      34.0; // legacy AddWasher/EditName 对话框水平外边距 34dp
  static const double bottomCharacterSize =
      132.0; // legacy order_bottom_character 132dp
  static const double bottomCharacterContentPadding =
      124.0; // legacy 带底部角色页面内容底部预留 124dp
  static const double bottomCharacterSeamPadding =
      48.0; // legacy 底部角色 padding(bottom=48dp+navBottom)：< 底栏 68dp → 卡在交界（问题8）

  // ========== Module B2 - DrinkingWater 模块还原尺寸 ==========
  static const double infoLineLabelWidth = 70.0; // legacy InfoLine 标签列定宽 70dp
  static const double drinkingIconSize =
      34.0; // legacy DrinkingWaterScreen 饮水机图标 34dp
  static const double drinkingCardGap = 10.0; // legacy 饮水卡内/卡间垂直间距 10dp
  static const double drinkingContentTopGap = 14.0; // legacy 饮水页内容顶部留白 14dp

  // ========== Module P1 - Profile 模块还原尺寸 ==========
  // 命名严格对照 legacy ShuiScreens.kt ProfileScreen / BathSystemEntryCard +
  // ShuiComponents.kt AccountCard 的 dp 值，集中于此保持单一事实来源。
  static const double profileTopCharacterSize =
      104.0; // legacy profile_top_character 104dp
  static const double profileBottomDecorSize =
      258.0; // legacy shui_wode_bottom 258dp
  static const double profileBottomDecorHeight =
      86.0; // legacy 底部装饰容器高度 86dp
  static const double accountLogoSize = 42.0; // legacy 账号 logo / 浴室系统 logo 42dp
  static const double accountSmallIconSize =
      22.0; // legacy AccountServiceRow / mini action 图标 22dp
  static const double accountLoginButtonWidth =
      96.0; // legacy BathSystem「点击登录」按钮宽 96dp
  static const double accountDividerWidth = 82.0; // legacy 标题行右侧分隔线 82dp

  // ========== Phase 2 - 文本截断修复 ==========
  /// StatusPill 宽度宽松上限（P2）：取代旧的 126dp 硬限（会裁状态串）。
  /// 仅防极端超长；状态默认按内容 + 父级约束自适应 + maxLines:2 换行。
  static const double statusPillMaxWidth = 200.0;

  // ========== Module P2 - AccountDetail 登录页还原尺寸 ==========
  static const double smsButtonWidth =
      92.0; // legacy UjingAccountDetail「发送验证码」按钮宽 92dp
  static const double smsButtonHeight =
      52.0; // legacy 发送验证码按钮高 52dp（与输入框对齐）
  static const int smsCooldownSeconds = 30; // legacy 验证码 30s cooldown
  static const double formFieldGap = 10.0; // legacy 登录卡内字段垂直间距 10dp

  // ========== Module P3 - 慧生活798 登录页还原尺寸 ==========
  static const double captchaBoxHeight =
      84.0; // legacy Shower798 图形验证码框高 84dp
  static const double captchaBoxPadding = 8.0; // legacy 验证码图内边距 8dp

  // ========== Module W1 - Washer 下单页还原尺寸 ==========
  static const double optionCardHeight = 48.0; // legacy OptionCard 无副标题高 48dp
  static const double optionCardTallHeight =
      86.0; // legacy OptionCard 带副标题高 86dp
  static const double optionCardIconSize = 22.0; // legacy OptionCard 行内图标 22dp
  static const double optionCardIconLarge =
      31.0; // legacy OptionCard 竖排图标 31dp
  static const double optionCheckSize = 20.0; // legacy 选中角标 20dp
  static const double optionStroke = 1.3; // legacy OptionCard 描边 1.3dp
  static const double washerMachineInfoSize =
      74.0; // legacy WasherRuntimeInfoCard 机器图 74dp

  // ========== Module W2 - Orders 聚合页还原尺寸 ==========
  static const double categoryChipHeight = 44.0; // legacy CategoryChip 高 44dp
  static const double categoryChipRadius = 9.0; // legacy CategoryChip 圆角 9dp
  static const double categoryChipIconSize = 22.0; // legacy CategoryChip 图标 22dp
  static const double orderItemIconSize = 28.0; // legacy OrderListItem 图标 28dp
  static const double orderItemRowGap = 16.0; // legacy OrderListItem 两行间距 16dp
}
