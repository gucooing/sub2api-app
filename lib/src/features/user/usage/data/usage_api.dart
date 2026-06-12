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

class UsageApi {
  UsageApi(this._client);

  final ApiClient _client;

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
