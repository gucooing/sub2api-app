import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';

/// 平台统计。
@immutable
class PlatformStats {
  const PlatformStats({
    required this.platform,
    required this.totalRequests,
    required this.totalTokens,
    required this.totalActualCost,
    required this.todayRequests,
    required this.todayTokens,
    required this.todayActualCost,
  });

  final String platform;
  final int totalRequests;
  final int totalTokens;
  final double totalActualCost;
  final int todayRequests;
  final int todayTokens;
  final double todayActualCost;

  factory PlatformStats.fromJson(Map<String, dynamic> json) {
    return PlatformStats(
      platform: json['platform'] as String? ?? '',
      totalRequests: (json['total_requests'] as num?)?.toInt() ?? 0,
      totalTokens: (json['total_tokens'] as num?)?.toInt() ?? 0,
      totalActualCost: (json['total_actual_cost'] as num?)?.toDouble() ?? 0,
      todayRequests: (json['today_requests'] as num?)?.toInt() ?? 0,
      todayTokens: (json['today_tokens'] as num?)?.toInt() ?? 0,
      todayActualCost: (json['today_actual_cost'] as num?)?.toDouble() ?? 0,
    );
  }
}

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
    this.byPlatform = const [],
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
  final List<PlatformStats> byPlatform;

  factory UserDashboardStats.fromJson(Map<String, dynamic> json) {
    int asInt(String key) => (json[key] as num?)?.toInt() ?? 0;
    double asDouble(String key) => (json[key] as num?)?.toDouble() ?? 0;

    final platformList = json['by_platform'] as List? ?? const [];
    final platforms = platformList
        .whereType<Map>()
        .map((e) => PlatformStats.fromJson(e.cast<String, dynamic>()))
        .toList();

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
      byPlatform: platforms,
    );
  }
}

/// 趋势数据点(`/usage/dashboard/trend` 的 `trend[]`),同时含请求/Token/消耗,
/// 以便总览同一份数据画「消耗」与「Tokens」两条趋势。
@immutable
class DashboardTrendPoint {
  const DashboardTrendPoint({
    required this.date,
    required this.requests,
    required this.totalTokens,
    required this.cost,
    required this.actualCost,
  });

  /// 原始日期标签(day 粒度 `2026-06-13`,hour 粒度 `2026-06-13 08:00`)。
  final String date;
  final int requests;
  final int totalTokens;
  final double cost;
  final double actualCost;

  factory DashboardTrendPoint.fromJson(Map<String, dynamic> json) {
    final cost = (json['cost'] as num?)?.toDouble() ?? 0;
    return DashboardTrendPoint(
      date: json['date'] as String? ?? '',
      requests: (json['requests'] as num?)?.toInt() ?? 0,
      totalTokens: (json['total_tokens'] as num?)?.toInt() ?? 0,
      cost: cost,
      actualCost: (json['actual_cost'] as num?)?.toDouble() ?? cost,
    );
  }

  /// `2026-06-13` → `06-13`;hour 粒度 `2026-06-13 08:00` → `08:00`。
  String get shortLabel {
    if (date.contains(':')) {
      final parts = date.split(' ');
      return parts.length > 1 ? parts[1] : date;
    }
    final parts = date.split('-');
    return parts.length >= 3 ? '${parts[1]}-${parts[2]}' : date;
  }
}

class DashboardApi {
  DashboardApi(this._client);

  final ApiClient _client;

  Future<UserDashboardStats> stats() async {
    final data = await _client.get<dynamic>('/usage/dashboard/stats');
    return UserDashboardStats.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 用量趋势(默认最近 [days] 天,day 粒度)。
  Future<List<DashboardTrendPoint>> trend({int days = 7}) async {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: days - 1));
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final data = await _client.get<dynamic>('/usage/dashboard/trend', query: {
      'start_date': fmt(start),
      'end_date': fmt(now),
      'granularity': 'day',
    });
    final list = (data as Map)['trend'] as List? ?? const [];
    return list
        .whereType<Map>()
        .map((e) => DashboardTrendPoint.fromJson(e.cast<String, dynamic>()))
        .toList();
  }
}
