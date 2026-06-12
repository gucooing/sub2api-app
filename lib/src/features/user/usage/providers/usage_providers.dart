import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client_provider.dart';
import '../data/usage_api.dart';

/// 用量页时间范围类型。
enum UsageRangeType { today, week, month, custom }

/// 日期范围。
class DateRange {
  const DateRange({
    required this.start,
    required this.end,
    required this.type,
  });

  final DateTime start;
  final DateTime end;
  final UsageRangeType type;

  String get startDate => _fmt(start);
  String get endDate => _fmt(end);

  int get days => end.difference(start).inDays + 1;

  String get granularity => days <= 1 ? 'hour' : 'day';

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// 创建预设范围。
  factory DateRange.preset(UsageRangeType type) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return switch (type) {
      UsageRangeType.today => DateRange(
          start: today,
          end: today,
          type: UsageRangeType.today,
        ),
      UsageRangeType.week => DateRange(
          start: today.subtract(const Duration(days: 6)),
          end: today,
          type: UsageRangeType.week,
        ),
      UsageRangeType.month => DateRange(
          start: today.subtract(const Duration(days: 29)),
          end: today,
          type: UsageRangeType.month,
        ),
      UsageRangeType.custom => throw ArgumentError('Use DateRange() for custom'),
    };
  }
}

final usageApiProvider = Provider<UsageApi>(
  (ref) => UsageApi(ref.watch(apiClientProvider)),
);

/// 当前选中的日期范围。
final usageDateRangeProvider =
    NotifierProvider<UsageDateRangeController, DateRange>(
  UsageDateRangeController.new,
);

class UsageDateRangeController extends Notifier<DateRange> {
  @override
  DateRange build() => DateRange.preset(UsageRangeType.week);

  void setPreset(UsageRangeType type) {
    if (type == UsageRangeType.custom) return;
    state = DateRange.preset(type);
  }

  void setCustom(DateTime start, DateTime end) {
    state = DateRange(start: start, end: end, type: UsageRangeType.custom);
  }
}

final usageTrendProvider =
    FutureProvider.autoDispose<List<TrendPoint>>((ref) {
  final range = ref.watch(usageDateRangeProvider);
  return ref.watch(usageApiProvider).trend(
        startDate: range.startDate,
        endDate: range.endDate,
        granularity: range.granularity,
      );
});

final usageModelsProvider =
    FutureProvider.autoDispose<List<ModelUsageStat>>((ref) {
  final range = ref.watch(usageDateRangeProvider);
  return ref
      .watch(usageApiProvider)
      .models(startDate: range.startDate, endDate: range.endDate);
});
