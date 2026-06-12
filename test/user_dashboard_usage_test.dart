import 'package:flutter_test/flutter_test.dart';
import 'package:sub2api/src/features/user/dashboard/data/dashboard_api.dart';
import 'package:sub2api/src/features/user/usage/data/usage_api.dart';
import 'package:sub2api/src/features/user/usage/providers/usage_providers.dart';

void main() {
  test('UserDashboardStats.fromJson 解析并容忍缺字段', () {
    final stats = UserDashboardStats.fromJson({
      'total_api_keys': 3,
      'active_api_keys': 2,
      'total_requests': 100,
      'total_tokens': 5000,
      'total_actual_cost': 1.23,
      'today_requests': 10,
      'today_tokens': 800,
      'today_actual_cost': 0.05,
      'average_duration_ms': 1234.5,
      'rpm': 1.5,
      'tpm': 300,
    });
    expect(stats.totalApiKeys, 3);
    expect(stats.todayActualCost, 0.05);
    expect(stats.tpm, 300);

    final empty = UserDashboardStats.fromJson(const {});
    expect(empty.totalRequests, 0);
    expect(empty.totalActualCost, 0);
  });

  test('TrendPoint/ModelUsageStat 解析,actual_cost 缺失回退 cost', () {
    final p = TrendPoint.fromJson({
      'date': '2026-06-13',
      'requests': 5,
      'total_tokens': 100,
      'cost': 0.5,
    });
    expect(p.actualCost, 0.5);

    final m = ModelUsageStat.fromJson({
      'model': 'claude-fable-5',
      'requests': 7,
      'total_tokens': 999,
      'actual_cost': 0.9,
      'cost': 1.5,
    });
    expect(m.actualCost, 0.9);
    expect(m.model, 'claude-fable-5');
  });

  test('UsageRange 日期区间与粒度', () {
    expect(UsageRange.today.granularity, 'hour');
    expect(UsageRange.week.granularity, 'day');

    final week = rangeDates(UsageRange.week);
    final start = DateTime.parse(week.start);
    final end = DateTime.parse(week.end);
    expect(end.difference(start).inDays, 6);

    final today = rangeDates(UsageRange.today);
    expect(today.start, today.end);
  });
}
