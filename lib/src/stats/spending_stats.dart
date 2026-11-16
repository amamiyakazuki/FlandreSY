import 'package:flutter/foundation.dart';

import '../runtime/models/hotwater_history.dart';
import '../runtime/models/washer_order.dart';
import '../runtime/shui_home_state.dart';

/// 统计的服务，顺序固定（也决定图表颜色的分配顺序）。
enum SpendingService {
  washer('洗衣'),
  drinking('饮水'),
  hotwater('热水');

  const SpendingService(this.label);
  final String label;
}

/// 年月（月份 1–12）。
@immutable
class MonthKey implements Comparable<MonthKey> {
  const MonthKey(this.year, this.month);

  factory MonthKey.fromMillis(int millis) {
    final t = DateTime.fromMillisecondsSinceEpoch(millis);
    return MonthKey(t.year, t.month);
  }

  final int year;
  final int month;

  MonthKey shift(int months) {
    final index = year * 12 + (month - 1) + months;
    return MonthKey(index ~/ 12, index % 12 + 1);
  }

  @override
  int compareTo(MonthKey other) =>
      (year * 12 + month).compareTo(other.year * 12 + other.month);

  @override
  bool operator ==(Object other) =>
      other is MonthKey && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => '$year年$month月';
}

@immutable
class ServiceSpend {
  const ServiceSpend(this.service, this.amountFen, this.count);

  final SpendingService service;
  final int amountFen;
  final int count;
}

/// 某个月的消费：各服务金额（分）与笔数。
@immutable
class MonthSpending {
  const MonthSpending(this.month, this.services);

  final MonthKey month;

  /// 按 [SpendingService] 顺序，三项都有（没有消费时为 0）。
  final List<ServiceSpend> services;

  int get totalFen => services.fold(0, (sum, s) => sum + s.amountFen);
  int get count => services.fold(0, (sum, s) => sum + s.count);
}

/// 基于本机订单记录的消费统计。
///
/// 计入规则：洗衣只算已完成订单；饮水算已扣费的完成订单；热水算住理账号记录。
/// 已登录时只统计当前账号的记录，与订单页一致。缺少日期的旧记录单独计数，不计入任何月份。
class SpendingStats {
  SpendingStats._(this._byMonth, this.undatedCount);

  final Map<MonthKey, Map<SpendingService, (int, int)>> _byMonth;

  /// 缺少日期、无法归入月份的记录数。
  final int undatedCount;

  bool get isEmpty => _byMonth.isEmpty;

  /// 有记录的最早月份；没有记录时为 null。
  MonthKey? get firstMonth =>
      _byMonth.isEmpty ? null : (_byMonth.keys.toList()..sort()).first;

  MonthSpending month(MonthKey key) {
    final entry = _byMonth[key] ?? const {};
    return MonthSpending(key, [
      for (final service in SpendingService.values)
        ServiceSpend(service, entry[service]?.$1 ?? 0, entry[service]?.$2 ?? 0),
    ]);
  }

  /// 以 [end] 结尾的连续 [count] 个月（含没有消费的月份）。
  List<MonthSpending> recentMonths(MonthKey end, int count) =>
      [for (var i = count - 1; i >= 0; i--) month(end.shift(-i))];

  static SpendingStats compute(ShuiHomeState state) {
    final byMonth = <MonthKey, Map<SpendingService, (int, int)>>{};
    var undated = 0;
    void add(SpendingService service, int atMillis, int fen) {
      if (fen <= 0) return;
      if (atMillis <= 0) {
        undated++;
        return;
      }
      final services =
          byMonth.putIfAbsent(MonthKey.fromMillis(atMillis), () => {});
      final (amount, count) = services[service] ?? (0, 0);
      services[service] = (amount + fen, count + 1);
    }

    final ujing = state.ujingAccountKey;
    bool ujingVisible(String owner) =>
        ujing.isEmpty || owner.isEmpty || owner == ujing;

    for (final h in state.washer.history) {
      if (h.status != WasherStatus.finished ||
          !ujingVisible(h.ownerAccountKey)) {
        continue;
      }
      add(SpendingService.washer, h.createdAtMillis,
          parseYuanToFen(h.payPrice));
    }
    for (final h in state.waterHistory) {
      if (!ujingVisible(h.ownerAccountKey)) continue;
      add(SpendingService.drinking, h.completedAtMillis,
          (h.payment * 100).round());
    }
    for (final HotwaterHistoryUi h in state.currentHotwaterHistory) {
      add(SpendingService.hotwater, h.timeMillis ?? 0,
          parseYuanToFen(h.amount));
    }
    return SpendingStats._(byMonth, undated);
  }
}

/// 「¥2.10」「2.1」等金额文本 → 分；无法解析返回 0。
int parseYuanToFen(String text) {
  final match = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(text);
  if (match == null) return 0;
  final value = double.tryParse(match.group(0)!);
  return value == null ? 0 : (value * 100).round();
}

/// 分 → 「¥x.xx」。
String formatFen(int fen) => '¥${(fen / 100).toStringAsFixed(2)}';
