import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client_provider.dart';
import '../data/admin_dashboard_api.dart';

final adminDashboardApiProvider = Provider<AdminDashboardApi>(
  (ref) => AdminDashboardApi(ref.watch(apiClientProvider)),
);

/// 管理端总览统计;下拉刷新用 `ref.invalidate` 重新拉取。
final adminDashboardStatsProvider =
    FutureProvider.autoDispose<AdminDashboardStats>((ref) {
  return ref.watch(adminDashboardApiProvider).stats();
});

/// 最近 7 天用量趋势(多线图)。
final adminDashboardTrendProvider =
    FutureProvider.autoDispose<List<DashboardTrendPoint>>((ref) {
  return ref.watch(adminDashboardApiProvider).trend();
});
