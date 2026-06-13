import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';

@immutable
class UsageLog {
  const UsageLog({
    required this.id,
    required this.userId,
    required this.apiKeyId,
    required this.model,
    required this.provider,
    required this.rawJson,
    this.accountId,
    this.requestId,
    this.createdAt,
    this.finishedAt,
    this.status,
    this.serviceTier,
    this.reasoningEffort,
    this.inboundEndpoint,
    this.upstreamEndpoint,
    this.inputTokens,
    this.outputTokens,
    this.cacheCreationTokens,
    this.cacheReadTokens,
    this.cacheCreation5mTokens,
    this.cacheCreation1hTokens,
    this.totalTokens,
    this.cost,
    this.inputCost,
    this.outputCost,
    this.cacheCreationCost,
    this.cacheReadCost,
    this.totalCost,
    this.actualCost,
    this.rateMultiplier,
    this.billingType,
    this.requestType,
    this.durationMs,
    this.firstTokenMs,
    this.apiKeyName,
    this.groupId,
    this.groupName,
    this.subscriptionId,
    this.stream,
    this.openAIWSMode,
    this.imageCount,
    this.imageSize,
    this.imageInputSize,
    this.imageOutputSize,
    this.imageOutputTokens,
    this.imageOutputCost,
    this.imageSizeSource,
    this.imageSizeBreakdown,
    this.mediaType,
    this.userAgent,
    this.cacheTtlOverridden,
    this.billingMode,
  });

  final int id;
  final int userId;
  final int apiKeyId;
  final String model;
  final String provider;
  final Map<String, dynamic> rawJson;
  final int? accountId;
  final String? requestId;
  final DateTime? createdAt;
  final DateTime? finishedAt;
  final String? status;
  final String? serviceTier;
  final String? reasoningEffort;
  final String? inboundEndpoint;
  final String? upstreamEndpoint;
  final int? inputTokens;
  final int? outputTokens;
  final int? cacheCreationTokens;
  final int? cacheReadTokens;
  final int? cacheCreation5mTokens;
  final int? cacheCreation1hTokens;
  final int? totalTokens;
  final double? cost;
  final double? inputCost;
  final double? outputCost;
  final double? cacheCreationCost;
  final double? cacheReadCost;
  final double? totalCost;
  final double? actualCost;
  final double? rateMultiplier;
  final int? billingType;
  final String? requestType;
  final int? durationMs;
  final int? firstTokenMs;
  final String? apiKeyName;
  final int? groupId;
  final String? groupName;
  final int? subscriptionId;
  final bool? stream;
  final bool? openAIWSMode;
  final int? imageCount;
  final String? imageSize;
  final String? imageInputSize;
  final String? imageOutputSize;
  final int? imageOutputTokens;
  final double? imageOutputCost;
  final String? imageSizeSource;
  final Map<String, int>? imageSizeBreakdown;
  final String? mediaType;
  final String? userAgent;
  final bool? cacheTtlOverridden;
  final String? billingMode;

  double? get standardCost => totalCost ?? cost;

  int get totalTokenCount =>
      totalTokens ??
      (inputTokens ?? 0) +
          (outputTokens ?? 0) +
          (cacheCreationTokens ?? 0) +
          (cacheReadTokens ?? 0);

  factory UsageLog.fromJson(Map<String, dynamic> json) {
    final apiKey = json['api_key'];
    final group = json['group'];
    final inputTokens = _asInt(json['input_tokens']);
    final outputTokens = _asInt(json['output_tokens']);
    final cacheCreationTokens = _asInt(json['cache_creation_tokens']);
    final cacheReadTokens = _asInt(json['cache_read_tokens']);
    final computedTotal =
        inputTokens != null ||
            outputTokens != null ||
            cacheCreationTokens != null ||
            cacheReadTokens != null
        ? (inputTokens ?? 0) +
              (outputTokens ?? 0) +
              (cacheCreationTokens ?? 0) +
              (cacheReadTokens ?? 0)
        : null;

    return UsageLog(
      id: (json['id'] as num).toInt(),
      userId: (json['user_id'] as num).toInt(),
      apiKeyId: (json['api_key_id'] as num).toInt(),
      accountId: _asInt(json['account_id']),
      requestId: _asString(json['request_id']),
      model: json['model'] as String? ?? '',
      provider:
          _asString(json['provider']) ??
          (group is Map ? _asString(group['platform']) : null) ??
          '',
      rawJson: Map<String, dynamic>.unmodifiable(json),
      createdAt: _asDateTime(json['created_at']),
      finishedAt: _asDateTime(json['finished_at']),
      status: _asString(json['status']),
      serviceTier: _asString(json['service_tier']),
      reasoningEffort: _asString(json['reasoning_effort']),
      inboundEndpoint: _asString(json['inbound_endpoint']),
      upstreamEndpoint: _asString(json['upstream_endpoint']),
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      cacheCreationTokens: cacheCreationTokens,
      cacheReadTokens: cacheReadTokens,
      cacheCreation5mTokens: _asInt(json['cache_creation_5m_tokens']),
      cacheCreation1hTokens: _asInt(json['cache_creation_1h_tokens']),
      totalTokens: _asInt(json['total_tokens']) ?? computedTotal,
      cost: _asDouble(json['cost']) ?? _asDouble(json['total_cost']),
      inputCost: _asDouble(json['input_cost']),
      outputCost: _asDouble(json['output_cost']),
      cacheCreationCost: _asDouble(json['cache_creation_cost']),
      cacheReadCost: _asDouble(json['cache_read_cost']),
      totalCost: _asDouble(json['total_cost']),
      actualCost: _asDouble(json['actual_cost']),
      rateMultiplier: _asDouble(json['rate_multiplier']),
      billingType: _asInt(json['billing_type']),
      requestType: _asString(json['request_type']),
      durationMs: _asInt(json['duration_ms']),
      firstTokenMs: _asInt(json['first_token_ms']),
      apiKeyName: apiKey is Map ? _asString(apiKey['name']) : null,
      groupId: _asInt(json['group_id']),
      groupName: group is Map ? _asString(group['name']) : null,
      subscriptionId: _asInt(json['subscription_id']),
      stream: _asBool(json['stream']),
      openAIWSMode: _asBool(json['openai_ws_mode']),
      imageCount: _asInt(json['image_count']),
      imageSize: _asString(json['image_size']),
      imageInputSize: _asString(json['image_input_size']),
      imageOutputSize: _asString(json['image_output_size']),
      imageOutputTokens: _asInt(json['image_output_tokens']),
      imageOutputCost: _asDouble(json['image_output_cost']),
      imageSizeSource: _asString(json['image_size_source']),
      imageSizeBreakdown: _asIntMap(json['image_size_breakdown']),
      mediaType: _asString(json['media_type']),
      userAgent: _asString(json['user_agent']),
      cacheTtlOverridden: _asBool(json['cache_ttl_overridden']),
      billingMode: _asString(json['billing_mode']),
    );
  }
}

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

class UsageLogsApi {
  UsageLogsApi(this._client);

  final ApiClient _client;

  Future<PaginatedUsageLogs> list({
    int page = 1,
    int pageSize = 20,
    int? apiKeyId,
    int? groupId,
    String? model,
    int? requestType,
    bool? stream,
    String? startDate,
    String? endDate,
    String sortOrder = 'desc',
  }) async {
    final data = await _client.get<dynamic>(
      '/usage',
      query: {
        'page': page,
        'page_size': pageSize,
        'api_key_id': ?apiKeyId,
        'group_id': ?groupId,
        if (model != null && model.isNotEmpty) 'model': model,
        'request_type': ?requestType,
        'stream': ?stream,
        'start_date': ?startDate,
        'end_date': ?endDate,
        'sort_order': sortOrder,
      },
    );
    return PaginatedUsageLogs.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<UsageLog> getById(int id) async {
    final data = await _client.get<dynamic>('/usage/$id');
    return UsageLog.fromJson((data as Map).cast<String, dynamic>());
  }
}

String? _asString(Object? value) {
  if (value is String && value.isNotEmpty) return value;
  return null;
}

int? _asInt(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

bool? _asBool(Object? value) {
  if (value is bool) return value;
  if (value is String) return bool.tryParse(value);
  return null;
}

DateTime? _asDateTime(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}

Map<String, int>? _asIntMap(Object? value) {
  if (value is! Map) return null;
  return value.map(
    (key, value) => MapEntry(key.toString(), _asInt(value) ?? 0),
  );
}
