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
    this.todayInputTokens = 0,
    this.todayOutputTokens = 0,
    this.todayCacheCreationTokens = 0,
    this.todayCacheReadTokens = 0,
    this.totalInputTokens = 0,
    this.totalOutputTokens = 0,
    this.totalCacheCreationTokens = 0,
    this.totalCacheReadTokens = 0,
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

  /// 今日 token 构成。
  final int todayInputTokens;
  final int todayOutputTokens;
  final int todayCacheCreationTokens;
  final int todayCacheReadTokens;

  /// 累计 token 构成。
  final int totalInputTokens;
  final int totalOutputTokens;
  final int totalCacheCreationTokens;
  final int totalCacheReadTokens;

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
      todayInputTokens: asInt('today_input_tokens'),
      todayOutputTokens: asInt('today_output_tokens'),
      todayCacheCreationTokens: asInt('today_cache_creation_tokens'),
      todayCacheReadTokens: asInt('today_cache_read_tokens'),
      totalInputTokens: asInt('total_input_tokens'),
      totalOutputTokens: asInt('total_output_tokens'),
      totalCacheCreationTokens: asInt('total_cache_creation_tokens'),
      totalCacheReadTokens: asInt('total_cache_read_tokens'),
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
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.cacheCreationTokens = 0,
    this.cacheReadTokens = 0,
  });

  /// 原始日期标签(day 粒度 `2026-06-13`,hour 粒度 `2026-06-13 08:00`)。
  final String date;
  final int requests;
  final int totalTokens;
  final double cost;
  final double actualCost;

  /// 该点的 token 构成(供总览多线趋势图分线绘制)。
  final int inputTokens;
  final int outputTokens;
  final int cacheCreationTokens;
  final int cacheReadTokens;

  /// 缓存命中率(%):cache_read /(input + cache_read + cache_creation),
  /// 与 web `TokenUsageTrend.vue` 同口径;无可缓存 token 时为 0。
  double get cacheHitRate {
    final prompt = inputTokens + cacheReadTokens + cacheCreationTokens;
    return prompt > 0 ? cacheReadTokens / prompt * 100 : 0;
  }

  factory DashboardTrendPoint.fromJson(Map<String, dynamic> json) {
    final cost = (json['cost'] as num?)?.toDouble() ?? 0;
    int asInt(String key) => (json[key] as num?)?.toInt() ?? 0;
    return DashboardTrendPoint(
      date: json['date'] as String? ?? '',
      requests: asInt('requests'),
      totalTokens: asInt('total_tokens'),
      cost: cost,
      actualCost: (json['actual_cost'] as num?)?.toDouble() ?? cost,
      inputTokens: asInt('input_tokens'),
      outputTokens: asInt('output_tokens'),
      cacheCreationTokens: asInt('cache_creation_tokens'),
      cacheReadTokens: asInt('cache_read_tokens'),
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

  /// 用量趋势。默认最近 [days] 天、day 粒度;[granularity]='hour' 时按小时。
  Future<List<DashboardTrendPoint>> trend({
    int days = 7,
    String granularity = 'day',
  }) async {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: days - 1));
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final data = await _client.get<dynamic>('/usage/dashboard/trend', query: {
      'start_date': fmt(start),
      'end_date': fmt(now),
      'granularity': granularity,
    });
    final list = (data as Map)['trend'] as List? ?? const [];
    return list
        .whereType<Map>()
        .map((e) => DashboardTrendPoint.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// 当天用量趋势(小时粒度),供总览主趋势图使用。
  Future<List<DashboardTrendPoint>> todayHourlyTrend() =>
      trend(days: 1, granularity: 'hour');
}
