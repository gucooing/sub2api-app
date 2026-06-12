import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';

/// `GET /usage/dashboard/stats` 的用户总览统计(客户端关心的字段)。
@immutable
class UserDashboardStats {
  const UserDashboardStats({
    required this.totalApiKeys,
    required this.activeApiKeys,
    required this.totalRequests,
    required this.totalTokens,
    required this.totalActualCost,
    required this.todayRequests,
    required this.todayTokens,
    required this.todayActualCost,
    required this.averageDurationMs,
    required this.rpm,
    required this.tpm,
  });

  final int totalApiKeys;
  final int activeApiKeys;
  final int totalRequests;
  final int totalTokens;
  final double totalActualCost;
  final int todayRequests;
  final int todayTokens;
  final double todayActualCost;
  final double averageDurationMs;
  final double rpm;
  final double tpm;

  factory UserDashboardStats.fromJson(Map<String, dynamic> json) {
    int asInt(String key) => (json[key] as num?)?.toInt() ?? 0;
    double asDouble(String key) => (json[key] as num?)?.toDouble() ?? 0;
    return UserDashboardStats(
      totalApiKeys: asInt('total_api_keys'),
      activeApiKeys: asInt('active_api_keys'),
      totalRequests: asInt('total_requests'),
      totalTokens: asInt('total_tokens'),
      totalActualCost: asDouble('total_actual_cost'),
      todayRequests: asInt('today_requests'),
      todayTokens: asInt('today_tokens'),
      todayActualCost: asDouble('today_actual_cost'),
      averageDurationMs: asDouble('average_duration_ms'),
      rpm: asDouble('rpm'),
      tpm: asDouble('tpm'),
    );
  }
}

class DashboardApi {
  DashboardApi(this._client);

  final ApiClient _client;

  Future<UserDashboardStats> stats() async {
    final data = await _client.get<dynamic>('/usage/dashboard/stats');
    return UserDashboardStats.fromJson((data as Map).cast<String, dynamic>());
  }
}
