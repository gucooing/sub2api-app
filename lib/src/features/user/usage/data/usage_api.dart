import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';

/// `GET /usage/dashboard/trend` 的单个数据点。
@immutable
class TrendPoint {
  const TrendPoint({
    required this.date,
    required this.requests,
    required this.totalTokens,
    required this.actualCost,
  });

  /// day 粒度为 `YYYY-MM-DD`,hour 粒度为含小时的时间串。
  final String date;
  final int requests;
  final int totalTokens;
  final double actualCost;

  factory TrendPoint.fromJson(Map<String, dynamic> json) => TrendPoint(
        date: json['date'] as String? ?? '',
        requests: (json['requests'] as num?)?.toInt() ?? 0,
        totalTokens: (json['total_tokens'] as num?)?.toInt() ?? 0,
        actualCost: (json['actual_cost'] as num?)?.toDouble() ??
            (json['cost'] as num?)?.toDouble() ??
            0,
      );
}

/// `GET /usage/dashboard/models` 的单模型统计。
@immutable
class ModelUsageStat {
  const ModelUsageStat({
    required this.model,
    required this.requests,
    required this.totalTokens,
    required this.actualCost,
  });

  final String model;
  final int requests;
  final int totalTokens;
  final double actualCost;

  factory ModelUsageStat.fromJson(Map<String, dynamic> json) =>
      ModelUsageStat(
        model: json['model'] as String? ?? '',
        requests: (json['requests'] as num?)?.toInt() ?? 0,
        totalTokens: (json['total_tokens'] as num?)?.toInt() ?? 0,
        actualCost: (json['actual_cost'] as num?)?.toDouble() ??
            (json['cost'] as num?)?.toDouble() ??
            0,
      );
}

/// `GET /usage/stats` 的区间汇总(含 token 构成,用于「缓存情况」展示)。
@immutable
class UsageStatsSummary {
  const UsageStatsSummary({
    required this.requests,
    required this.inputTokens,
    required this.outputTokens,
    required this.cacheCreationTokens,
    required this.cacheReadTokens,
    required this.totalTokens,
    required this.actualCost,
    required this.avgDurationMs,
  });

  final int requests;
  final int inputTokens;
  final int outputTokens;
  final int cacheCreationTokens;
  final int cacheReadTokens;
  final int totalTokens;
  final double actualCost;
  final double avgDurationMs;

  factory UsageStatsSummary.fromJson(Map<String, dynamic> json) {
    int i(String k) => (json[k] as num?)?.toInt() ?? 0;
    double d(String k) => (json[k] as num?)?.toDouble() ?? 0;
    return UsageStatsSummary(
      requests: i('total_requests'),
      inputTokens: i('total_input_tokens'),
      outputTokens: i('total_output_tokens'),
      cacheCreationTokens: i('total_cache_creation_tokens'),
      cacheReadTokens: i('total_cache_read_tokens'),
      totalTokens: i('total_tokens'),
      actualCost: d('total_actual_cost') == 0 && json['total_cost'] != null
          ? d('total_cost')
          : d('total_actual_cost'),
      avgDurationMs: d('average_duration_ms'),
    );
  }
}

class UsageApi {
  UsageApi(this._client);

  final ApiClient _client;

  /// 区间汇总统计(token 构成 + 消耗 + 请求)。
  Future<UsageStatsSummary> stats({
    required String startDate,
    required String endDate,
  }) async {
    final data = await _client.get<dynamic>('/usage/stats', query: {
      'start_date': startDate,
      'end_date': endDate,
    });
    return UsageStatsSummary.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 趋势数据。日期为 `YYYY-MM-DD`;[granularity] 为 `day` 或 `hour`。
  Future<List<TrendPoint>> trend({
    required String startDate,
    required String endDate,
    String granularity = 'day',
  }) async {
    final data = await _client.get<dynamic>('/usage/dashboard/trend', query: {
      'start_date': startDate,
      'end_date': endDate,
      'granularity': granularity,
    });
    final list = (data as Map)['trend'] as List? ?? const [];
    return list
        .whereType<Map>()
        .map((e) => TrendPoint.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// 按模型聚合统计。
  Future<List<ModelUsageStat>> models({
    required String startDate,
    required String endDate,
  }) async {
    final data = await _client.get<dynamic>('/usage/dashboard/models', query: {
      'start_date': startDate,
      'end_date': endDate,
    });
    final list = (data as Map)['models'] as List? ?? const [];
    return list
        .whereType<Map>()
        .map((e) => ModelUsageStat.fromJson(e.cast<String, dynamic>()))
        .toList();
  }
}
