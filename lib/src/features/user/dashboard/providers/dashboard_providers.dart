import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client_provider.dart';
import '../data/dashboard_api.dart';

final dashboardApiProvider = Provider<DashboardApi>(
  (ref) => DashboardApi(ref.watch(apiClientProvider)),
);

/// 用户总览统计;下拉刷新用 `ref.invalidate` 重新拉取。
final dashboardStatsProvider =
    FutureProvider.autoDispose<UserDashboardStats>((ref) {
  return ref.watch(dashboardApiProvider).stats();
});
