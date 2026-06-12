import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';

/// 使用记录日志。
@immutable
class UsageLog {
  const UsageLog({
    required this.id,
    required this.userId,
    required this.apiKeyId,
    required this.model,
    required this.provider,
    this.createdAt,
    this.finishedAt,
    this.status,
    this.inputTokens,
    this.outputTokens,
    this.cacheCreationTokens,
    this.cacheReadTokens,
    this.totalTokens,
    this.cost,
    this.actualCost,
    this.durationMs,
    this.apiKeyName,
  });

  final int id;
  final int userId;
  final int apiKeyId;
  final String model;
  final String provider;
  final DateTime? createdAt;
  final DateTime? finishedAt;
  final String? status;
  final int? inputTokens;
  final int? outputTokens;
  final int? cacheCreationTokens;
  final int? cacheReadTokens;
  final int? totalTokens;
  final double? cost;
  final double? actualCost;
  final int? durationMs;
  final String? apiKeyName;

  factory UsageLog.fromJson(Map<String, dynamic> json) {
    final apiKey = json['api_key'];
    return UsageLog(
      id: (json['id'] as num).toInt(),
      userId: (json['user_id'] as num).toInt(),
      apiKeyId: (json['api_key_id'] as num).toInt(),
      model: json['model'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)?.toLocal()
          : null,
      finishedAt: json['finished_at'] != null
          ? DateTime.tryParse(json['finished_at'] as String)?.toLocal()
          : null,
      status: json['status'] as String?,
      inputTokens: (json['input_tokens'] as num?)?.toInt(),
      outputTokens: (json['output_tokens'] as num?)?.toInt(),
      cacheCreationTokens: (json['cache_creation_tokens'] as num?)?.toInt(),
      cacheReadTokens: (json['cache_read_tokens'] as num?)?.toInt(),
      totalTokens: (json['total_tokens'] as num?)?.toInt(),
      cost: (json['cost'] as num?)?.toDouble(),
      actualCost: (json['actual_cost'] as num?)?.toDouble(),
      durationMs: (json['duration_ms'] as num?)?.toInt(),
      apiKeyName: apiKey is Map ? apiKey['name'] as String? : null,
    );
  }
}

/// 分页结果。
@immutable
class PaginatedUsageLogs {
  const PaginatedUsageLogs({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  final List<UsageLog> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  factory PaginatedUsageLogs.fromJson(Map<String, dynamic> json) {
    final items = json['items'] as List? ?? const [];
    return PaginatedUsageLogs(
      items: items
          .whereType<Map>()
          .map((e) => UsageLog.fromJson(e.cast<String, dynamic>()))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['page_size'] as num?)?.toInt() ?? 20,
      totalPages: (json['total_pages'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 使用记录 API。
class UsageLogsApi {
  UsageLogsApi(this._client);

  final ApiClient _client;

  /// 获取使用记录列表。
  Future<PaginatedUsageLogs> list({
    int page = 1,
    int pageSize = 20,
    int? apiKeyId,
  }) async {
    final data = await _client.get<dynamic>('/usage', query: {
      'page': page,
      'page_size': pageSize,
      if (apiKeyId != null) 'api_key_id': apiKeyId,
    });
    return PaginatedUsageLogs.fromJson((data as Map).cast<String, dynamic>());
  }
}
