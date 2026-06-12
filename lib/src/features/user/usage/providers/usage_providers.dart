import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client_provider.dart';
import '../data/usage_api.dart';

/// 用量页时间范围。
enum UsageRange { today, week, month }

extension UsageRangeX on UsageRange {
  int get days => switch (this) {
        UsageRange.today => 1,
        UsageRange.week => 7,
        UsageRange.month => 30,
      };

  String get granularity =>
      this == UsageRange.today ? 'hour' : 'day';
}

final usageApiProvider = Provider<UsageApi>(
  (ref) => UsageApi(ref.watch(apiClientProvider)),
);

/// 当前选中的时间范围。
final usageRangeProvider =
    NotifierProvider<UsageRangeController, UsageRange>(
        UsageRangeController.new);

class UsageRangeController extends Notifier<UsageRange> {
  @override
  UsageRange build() => UsageRange.week;

  void set(UsageRange range) => state = range;
}

/// 由 [usageRangeProvider] 推导的日期区间(本地时区,YYYY-MM-DD)。
({String start, String end}) rangeDates(UsageRange range) {
  final now = DateTime.now();
  final end = _fmt(now);
  final start = _fmt(now.subtract(Duration(days: range.days - 1)));
  return (start: start, end: end);
}

String _fmt(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

final usageTrendProvider =
    FutureProvider.autoDispose<List<TrendPoint>>((ref) {
  final range = ref.watch(usageRangeProvider);
  final dates = rangeDates(range);
  return ref.watch(usageApiProvider).trend(
        startDate: dates.start,
        endDate: dates.end,
        granularity: range.granularity,
      );
});

final usageModelsProvider =
    FutureProvider.autoDispose<List<ModelUsageStat>>((ref) {
  final range = ref.watch(usageRangeProvider);
  final dates = rangeDates(range);
  return ref
      .watch(usageApiProvider)
      .models(startDate: dates.start, endDate: dates.end);
});
