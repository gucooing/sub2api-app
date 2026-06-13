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

  test('DashboardTrendPoint 解析 token 构成并算命中率', () {
    final p = DashboardTrendPoint.fromJson({
      'date': '2026-06-13',
      'requests': 5,
      'total_tokens': 1000,
      'cost': 0.5,
      'input_tokens': 200,
      'output_tokens': 100,
      'cache_creation_tokens': 100,
      'cache_read_tokens': 300,
    });
    expect(p.inputTokens, 200);
    expect(p.cacheReadTokens, 300);
    expect(p.actualCost, 0.5); // actual_cost 缺失回退 cost
    // 命中率 = 300 /(200+300+100) * 100 = 50
    expect(p.cacheHitRate, closeTo(50, 1e-9));

    // 无可缓存 token 时命中率为 0,不抛除零。
    final empty = DashboardTrendPoint.fromJson(const {'date': 'x'});
    expect(empty.cacheHitRate, 0);
    expect(empty.inputTokens, 0);
  });

  test('DateRange 日期区间与粒度', () {
    final today = DateRange.preset(UsageRangeType.today);
    expect(today.granularity, 'hour');
    expect(today.days, 1);
    expect(today.startDate, today.endDate);

    final week = DateRange.preset(UsageRangeType.week);
    expect(week.granularity, 'day');
    expect(week.days, 7);

    final month = DateRange.preset(UsageRangeType.month);
    expect(month.days, 30);

    // 自定义范围
    final custom = DateRange(
      start: DateTime(2026, 6, 1),
      end: DateTime(2026, 6, 10),
      type: UsageRangeType.custom,
    );
    expect(custom.days, 10);
    expect(custom.startDate, '2026-06-01');
    expect(custom.endDate, '2026-06-10');
  });
}
