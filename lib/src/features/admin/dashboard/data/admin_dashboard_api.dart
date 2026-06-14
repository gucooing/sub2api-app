import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';
import '../../../user/dashboard/data/dashboard_api.dart' show DashboardTrendPoint;

export '../../../user/dashboard/data/dashboard_api.dart' show DashboardTrendPoint;

/// 管理端总览统计(`GET /admin/dashboard/stats`)。
///
/// 字段对齐后端 `DashboardStats`;客户端只取概览磁贴/健康度需要的部分。
@immutable
class AdminDashboardStats {
  const AdminDashboardStats({
    required this.totalUsers,
    required this.todayNewUsers,
    required this.activeUsers,
    required this.totalApiKeys,
    required this.activeApiKeys,
    required this.totalAccounts,
    required this.normalAccounts,
    required this.errorAccounts,
    required this.ratelimitAccounts,
    required this.overloadAccounts,
    required this.totalRequests,
    required this.totalTokens,
    required this.totalActualCost,
    required this.todayRequests,
    required this.todayTokens,
    required this.todayActualCost,
    required this.averageDurationMs,
    required this.rpm,
    this.todayInputTokens = 0,
    this.todayOutputTokens = 0,
    this.todayCacheCreationTokens = 0,
    this.todayCacheReadTokens = 0,
    this.totalInputTokens = 0,
    this.totalOutputTokens = 0,
    this.totalCacheCreationTokens = 0,
    this.totalCacheReadTokens = 0,
  });

  // 用户
  final int totalUsers;
  final int todayNewUsers;
  final int activeUsers;

  // 密钥
  final int totalApiKeys;
  final int activeApiKeys;

  // 上游账号(健康度)
  final int totalAccounts;
  final int normalAccounts;
  final int errorAccounts;
  final int ratelimitAccounts;
  final int overloadAccounts;

  // 用量
  final int totalRequests;
  final int totalTokens;
  final double totalActualCost;
  final int todayRequests;
  final int todayTokens;
  final double todayActualCost;

  // 系统
  final double averageDurationMs;
  final double rpm;

  // 今日 token 构成
  final int todayInputTokens;
  final int todayOutputTokens;
  final int todayCacheCreationTokens;
  final int todayCacheReadTokens;

  // 累计 token 构成
  final int totalInputTokens;
  final int totalOutputTokens;
  final int totalCacheCreationTokens;
  final int totalCacheReadTokens;

  /// 异常账号合计(error + ratelimit + overload),供健康度概览。
  int get unhealthyAccounts =>
      errorAccounts + ratelimitAccounts + overloadAccounts;

  factory AdminDashboardStats.fromJson(Map<String, dynamic> json) {
    int asInt(String key) => (json[key] as num?)?.toInt() ?? 0;
    double asDouble(String key) => (json[key] as num?)?.toDouble() ?? 0;
    return AdminDashboardStats(
      totalUsers: asInt('total_users'),
      todayNewUsers: asInt('today_new_users'),
      activeUsers: asInt('active_users'),
      totalApiKeys: asInt('total_api_keys'),
      activeApiKeys: asInt('active_api_keys'),
      totalAccounts: asInt('total_accounts'),
      normalAccounts: asInt('normal_accounts'),
      errorAccounts: asInt('error_accounts'),
      ratelimitAccounts: asInt('ratelimit_accounts'),
      overloadAccounts: asInt('overload_accounts'),
      totalRequests: asInt('total_requests'),
      totalTokens: asInt('total_tokens'),
      totalActualCost: asDouble('total_actual_cost'),
      todayRequests: asInt('today_requests'),
      todayTokens: asInt('today_tokens'),
      todayActualCost: asDouble('today_actual_cost'),
      averageDurationMs: asDouble('average_duration_ms'),
      rpm: asDouble('rpm'),
      todayInputTokens: asInt('today_input_tokens'),
      todayOutputTokens: asInt('today_output_tokens'),
      todayCacheCreationTokens: asInt('today_cache_creation_tokens'),
      todayCacheReadTokens: asInt('today_cache_read_tokens'),
      totalInputTokens: asInt('total_input_tokens'),
      totalOutputTokens: asInt('total_output_tokens'),
      totalCacheCreationTokens: asInt('total_cache_creation_tokens'),
      totalCacheReadTokens: asInt('total_cache_read_tokens'),
    );
  }
}

/// 管理端总览 API。
class AdminDashboardApi {
  AdminDashboardApi(this._client);

  final ApiClient _client;

  Future<AdminDashboardStats> stats() async {
    final data = await _client.get<dynamic>('/admin/dashboard/stats');
    return AdminDashboardStats.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 用量趋势。默认最近 [days] 天 day 粒度;[granularity]='hour' 时按小时。
  Future<List<DashboardTrendPoint>> trend({
    int days = 7,
    String granularity = 'day',
  }) async {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: days - 1));
    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final data = await _client.get<dynamic>(
      '/admin/dashboard/trend',
      query: {
        'start_date': fmt(start),
        'end_date': fmt(now),
        'granularity': granularity,
      },
    );
    final map = (data as Map).cast<String, dynamic>();
    final list = map['trend'] as List? ?? const [];
    return list
        .whereType<Map>()
        .map((e) => DashboardTrendPoint.fromJson(e.cast<String, dynamic>()))
        .toList();
  }
}
