import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../runtime/shui_runtime.dart';
import '../widgets/shui_components.dart';
import '../widgets/shui_header.dart';
import 'spending_stats.dart';

/// 图表中各服务的颜色（按服务固定，不随排名变化），与应用其他地方一致。
/// 配色在界面重构时统一重新确定。
const Map<SpendingService, Color> kSpendingColors = {
  SpendingService.washer: AppColors.serviceOrange,
  SpendingService.drinking: AppColors.serviceBlue,
  SpendingService.hotwater: AppColors.primary,
};

/// 消费统计页：本月合计、按服务拆分、近 6 个月走势。
class SpendingScreen extends StatefulWidget {
  const SpendingScreen({
    required this.state,
    required this.nowMillis,
    required this.onBack,
    super.key,
  });

  final ShuiHomeState state;
  final int nowMillis;
  final VoidCallback onBack;

  @override
  State<SpendingScreen> createState() => _SpendingScreenState();
}

class _SpendingScreenState extends State<SpendingScreen> {
  static const int _trendMonths = 6;
  late MonthKey _selected = MonthKey.fromMillis(widget.nowMillis);

  MonthKey get _current => MonthKey.fromMillis(widget.nowMillis);

  @override
  Widget build(BuildContext context) {
    final stats = SpendingStats.compute(widget.state);
    final month = stats.month(_selected);
    final first = stats.firstMonth;
    final canGoBack = first != null && _selected.compareTo(first) > 0;
    final canGoForward = _selected.compareTo(_current) < 0;
    // 走势默认截止本月；翻到更早的月份时截止到所选月份，保证它在图里。
    final trendEnd =
        _selected.compareTo(_current.shift(-(_trendMonths - 1))) < 0
            ? _selected
            : _current;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: Column(
        children: [
          TopHeader(title: '消费统计', showBack: true, onBack: widget.onBack),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppCustomTokens.spaceMd,
                AppCustomTokens.spaceSm,
                AppCustomTokens.spaceMd,
                bottomInset + AppCustomTokens.spaceLg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MonthSwitcher(
                    month: _selected,
                    onPrevious: canGoBack
                        ? () => setState(() => _selected = _selected.shift(-1))
                        : null,
                    onNext: canGoForward
                        ? () => setState(() => _selected = _selected.shift(1))
                        : null,
                  ),
                  const SizedBox(height: AppCustomTokens.spaceSm),
                  SectionCard(child: _MonthSummary(month: month)),
                  const SizedBox(height: AppCustomTokens.spaceSm),
                  SectionCard(
                    child: _Trend(
                      months: stats.recentMonths(trendEnd, _trendMonths),
                      selected: _selected,
                      onSelect: (m) => setState(() => _selected = m),
                    ),
                  ),
                  const SizedBox(height: AppCustomTokens.spaceSm),
                  Text(
                    [
                      '根据本机订单记录统计：洗衣只计已完成订单，热水为当前住理账号的记录。',
                      if (stats.undatedCount > 0)
                        '另有 ${stats.undatedCount} 笔旧记录没有日期，未计入。',
                    ].join(''),
                    style: AppTypography.textTheme.bodySmall
                        ?.copyWith(color: AppColors.mutedText),
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

class _MonthSwitcher extends StatelessWidget {
  const _MonthSwitcher({required this.month, this.onPrevious, this.onNext});

  final MonthKey month;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onPrevious,
          tooltip: '上个月',
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            '$month',
            textAlign: TextAlign.center,
            style: AppTypography.textTheme.titleMedium
                ?.copyWith(color: AppColors.deepText),
          ),
        ),
        IconButton(
          onPressed: onNext,
          tooltip: '下个月',
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

/// 本月合计（大号数字）+ 按服务拆分的横向条。金额始终以文字给出，颜色只表示服务。
class _MonthSummary extends StatelessWidget {
  const _MonthSummary({required this.month});

  final MonthSpending month;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    final total = month.totalFen;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('合计',
            style: textTheme.bodySmall?.copyWith(color: AppColors.mutedText)),
        Text(formatFen(total),
            style:
                textTheme.headlineMedium?.copyWith(color: AppColors.deepText)),
        Text(total == 0 ? '这个月没有消费记录' : '共 ${month.count} 笔',
            style: textTheme.bodySmall?.copyWith(color: AppColors.mutedText)),
        const SizedBox(height: AppCustomTokens.spaceMd),
        for (final s in month.services) ...[
          _ServiceRow(spend: s, totalFen: total),
          const SizedBox(height: AppCustomTokens.spaceSm),
        ],
      ],
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({required this.spend, required this.totalFen});

  final ServiceSpend spend;
  final int totalFen;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    final share = totalFen == 0 ? 0.0 : spend.amountFen / totalFen;
    final color = kSpendingColors[spend.service]!;
    return Semantics(
      label: '${spend.service.label} ${formatFen(spend.amountFen)}，'
          '${spend.count} 笔',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  spend.count == 0
                      ? spend.service.label
                      : '${spend.service.label} · ${spend.count} 笔',
                  style:
                      textTheme.bodyMedium?.copyWith(color: AppColors.deepText),
                ),
              ),
              Text(formatFen(spend.amountFen),
                  style: textTheme.titleSmall
                      ?.copyWith(color: AppColors.deepText)),
            ],
          ),
          const SizedBox(height: AppCustomTokens.spaceXs),
          LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                if (share > 0)
                  Container(
                    height: 8,
                    width: (constraints.maxWidth * share)
                        .clamp(4.0, constraints.maxWidth),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 近 6 个月合计的柱状图（单一系列，单一色相）。选中月份为实色并标出金额，
/// 其余月份为浅色；点击柱子切换月份。
class _Trend extends StatelessWidget {
  const _Trend({
    required this.months,
    required this.selected,
    required this.onSelect,
  });

  static const double _plotHeight = 120;

  final List<MonthSpending> months;
  final MonthKey selected;
  final ValueChanged<MonthKey> onSelect;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    final max = months.fold<int>(0, (m, s) => s.totalFen > m ? s.totalFen : m);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('近 6 个月',
            style: textTheme.titleSmall?.copyWith(color: AppColors.deepText)),
        const SizedBox(height: AppCustomTokens.spaceSm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final m in months)
              Expanded(
                child: _TrendBar(
                  month: m,
                  max: max,
                  plotHeight: _plotHeight,
                  selected: m.month == selected,
                  onTap: () => onSelect(m.month),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _TrendBar extends StatelessWidget {
  const _TrendBar({
    required this.month,
    required this.max,
    required this.plotHeight,
    required this.selected,
    required this.onTap,
  });

  final MonthSpending month;
  final int max;
  final double plotHeight;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    final total = month.totalFen;
    final height = max == 0 || total == 0
        ? 0.0
        : (plotHeight * total / max).clamp(4.0, plotHeight);
    return Semantics(
      button: true,
      selected: selected,
      label: '${month.month}，${formatFen(total)}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppCustomTokens.radiusMedium),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(vertical: AppCustomTokens.spaceXs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 不固定高度：同一行的柱子底部对齐，选中月份的金额放在柱顶，
              // 大字号时整行自然变高，不会溢出。
              if (selected && total > 0)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(formatFen(total),
                      style: textTheme.labelSmall
                          ?.copyWith(color: AppColors.deepText)),
                ),
              const SizedBox(height: 2),
              Container(
                width: 20,
                height: height,
                decoration: BoxDecoration(
                  color:
                      AppColors.primary.withValues(alpha: selected ? 1 : 0.35),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ),
              Container(height: 1, color: AppColors.cardBorder),
              const SizedBox(height: AppCustomTokens.spaceXs),
              Text('${month.month.month}月',
                  style: textTheme.bodySmall?.copyWith(
                      color:
                          selected ? AppColors.deepText : AppColors.mutedText,
                      fontWeight: selected ? FontWeight.w600 : null)),
            ],
          ),
        ),
      ),
    );
  }
}
