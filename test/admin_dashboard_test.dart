import 'package:flutter_test/flutter_test.dart';
import 'package:sub2api/src/features/admin/dashboard/data/admin_dashboard_api.dart';

void main() {
  test('AdminDashboardStats.fromJson 解析平台/账号健康/用量字段', () {
    final stats = AdminDashboardStats.fromJson(const {
      'total_users': 1200,
      'today_new_users': 8,
      'active_users': 73,
      'total_api_keys': 540,
      'active_api_keys': 500,
      'total_accounts': 40,
      'normal_accounts': 34,
      'error_accounts': 3,
      'ratelimit_accounts': 2,
      'overload_accounts': 1,
      'total_requests': 1000000,
      'total_tokens': 9000000,
      'total_actual_cost': 1234.5,
      'today_requests': 5000,
      'today_tokens': 60000,
      'today_actual_cost': 12.34,
      'average_duration_ms': 850.0,
      'rpm': 42.5,
      'today_input_tokens': 100,
      'today_output_tokens': 200,
      'today_cache_creation_tokens': 30,
      'today_cache_read_tokens': 70,
    });

    expect(stats.totalUsers, 1200);
    expect(stats.todayNewUsers, 8);
    expect(stats.activeApiKeys, 500);
    expect(stats.totalAccounts, 40);
    expect(stats.normalAccounts, 34);
    // 异常合计 = error + ratelimit + overload。
    expect(stats.unhealthyAccounts, 6);
    expect(stats.todayActualCost, 12.34);
    expect(stats.rpm, 42.5);
  });

  test('AdminDashboardStats.fromJson 容忍缺字段', () {
    final stats = AdminDashboardStats.fromJson(const {});
    expect(stats.totalUsers, 0);
    expect(stats.totalAccounts, 0);
    expect(stats.unhealthyAccounts, 0);
    expect(stats.totalActualCost, 0);
  });

  test('DashboardTrendPoint 缓存命中率口径', () {
    final p = DashboardTrendPoint.fromJson(const {
      'date': '2026-06-14',
      'requests': 10,
      'input_tokens': 100,
      'output_tokens': 50,
      'cache_creation_tokens': 100,
      'cache_read_tokens': 300,
      'total_tokens': 550,
      'cost': 1.0,
      'actual_cost': 0.8,
    });
    // cache_read /(input + cache_read + cache_creation) = 300/500 = 60%
    expect(p.cacheHitRate, closeTo(60.0, 0.001));
    expect(p.shortLabel, '06-14');
  });
}
