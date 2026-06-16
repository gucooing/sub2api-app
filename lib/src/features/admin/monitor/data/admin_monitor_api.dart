import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';

/// 渠道监控状态:operational / degraded / failed / error
@immutable
class ExtraModelStatus {
  const ExtraModelStatus(
      {required this.model, this.status = '', this.latencyMs});
  final String model;
  final String status;
  final int? latencyMs;

  factory ExtraModelStatus.fromJson(Map<String, dynamic> j) => ExtraModelStatus(
        model: j['model'] as String? ?? '',
        status: j['status'] as String? ?? '',
        latencyMs: (j['latency_ms'] as num?)?.toInt(),
      );
}

@immutable
class ChannelMonitor {
  const ChannelMonitor({
    required this.id,
    required this.name,
    required this.provider,
    required this.endpoint,
    required this.primaryModel,
    this.apiMode = 'chat_completions',
    this.groupName = '',
    this.enabled = true,
    this.intervalSeconds = 0,
    this.lastCheckedAt,
    this.primaryStatus = '',
    this.primaryLatencyMs,
    this.availability7d = 0,
    this.extraModels = const [],
    this.extraModelsStatus = const [],
    this.apiKeyDecryptFailed = false,
  });

  final int id;
  final String name;
  final String provider; // openai / anthropic / gemini
  final String endpoint;
  final String primaryModel;
  final String apiMode;
  final String groupName;
  final bool enabled;
  final int intervalSeconds;
  final String? lastCheckedAt;
  final String primaryStatus;
  final int? primaryLatencyMs;
  final num availability7d;
  final List<String> extraModels;
  final List<ExtraModelStatus> extraModelsStatus;
  final bool apiKeyDecryptFailed;

  factory ChannelMonitor.fromJson(Map<String, dynamic> j) {
    final ex = <ExtraModelStatus>[];
    final raw = j['extra_models_status'];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) ex.add(ExtraModelStatus.fromJson(e.cast<String, dynamic>()));
      }
    }
    return ChannelMonitor(
      id: (j['id'] as num?)?.toInt() ?? 0,
      name: j['name'] as String? ?? '',
      provider: j['provider'] as String? ?? '',
      endpoint: j['endpoint'] as String? ?? '',
      primaryModel: j['primary_model'] as String? ?? '',
      apiMode: j['api_mode'] as String? ?? 'chat_completions',
      groupName: j['group_name'] as String? ?? '',
      enabled: j['enabled'] as bool? ?? true,
      intervalSeconds: (j['interval_seconds'] as num?)?.toInt() ?? 0,
      lastCheckedAt: j['last_checked_at'] as String?,
      primaryStatus: j['primary_status'] as String? ?? '',
      primaryLatencyMs: (j['primary_latency_ms'] as num?)?.toInt(),
      availability7d: j['availability_7d'] as num? ?? 0,
      extraModels: [
        for (final m in (j['extra_models'] as List? ?? const [])) '$m'
      ],
      extraModelsStatus: ex,
      apiKeyDecryptFailed: j['api_key_decrypt_failed'] as bool? ?? false,
    );
  }
}

@immutable
class ChannelMonitorPage {
  const ChannelMonitorPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pages,
  });

  final List<ChannelMonitor> items;
  final int total;
  final int page;
  final int pages;

  factory ChannelMonitorPage.fromJson(Map<String, dynamic> json) {
    final list = json['items'] as List? ?? const [];
    return ChannelMonitorPage(
      items: list
          .whereType<Map>()
          .map((e) => ChannelMonitor.fromJson(e.cast<String, dynamic>()))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pages: (json['pages'] as num?)?.toInt() ?? 1,
    );
  }
}

/// 检测结果 / 历史条目(同形)。
@immutable
class MonitorCheckItem {
  const MonitorCheckItem({
    required this.model,
    required this.status,
    this.latencyMs,
    this.pingLatencyMs,
    this.message = '',
    this.checkedAt,
  });

  final String model;
  final String status;
  final int? latencyMs;
  final int? pingLatencyMs;
  final String message;
  final String? checkedAt;

  factory MonitorCheckItem.fromJson(Map<String, dynamic> j) => MonitorCheckItem(
        model: j['model'] as String? ?? '',
        status: j['status'] as String? ?? '',
        latencyMs: (j['latency_ms'] as num?)?.toInt(),
        pingLatencyMs: (j['ping_latency_ms'] as num?)?.toInt(),
        message: j['message'] as String? ?? '',
        checkedAt: j['checked_at'] as String?,
      );
}

/// 管理端渠道监控 API。
class AdminChannelMonitorApi {
  AdminChannelMonitorApi(this._client);

  final ApiClient _client;

  Future<ChannelMonitorPage> list({
    int page = 1,
    int pageSize = 20,
    String? provider,
    bool? enabled,
    String? search,
  }) async {
    final data = await _client.get<dynamic>('/admin/channel-monitors', query: {
      'page': page,
      'page_size': pageSize,
      if (provider != null && provider.isNotEmpty) 'provider': provider,
      'enabled': ?enabled,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return ChannelMonitorPage.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<ChannelMonitor> getById(int id) async {
    final data = await _client.get<dynamic>('/admin/channel-monitors/$id');
    return ChannelMonitor.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<void> setEnabled(int id, bool enabled) =>
      _client.put<dynamic>('/admin/channel-monitors/$id', data: {'enabled': enabled});

  Future<void> delete(int id) =>
      _client.delete<dynamic>('/admin/channel-monitors/$id');

  /// 立即检测,返回各模型结果。
  Future<List<MonitorCheckItem>> runNow(int id) async {
    final data =
        await _client.post<dynamic>('/admin/channel-monitors/$id/run');
    final list = (data is Map ? data['results'] : null) as List? ?? const [];
    return [
      for (final e in list)
        if (e is Map) MonitorCheckItem.fromJson(e.cast<String, dynamic>()),
    ];
  }

  /// 检测历史。
  Future<List<MonitorCheckItem>> history(int id,
      {String? model, int limit = 50}) async {
    final data = await _client
        .get<dynamic>('/admin/channel-monitors/$id/history', query: {
      'limit': limit,
      if (model != null && model.isNotEmpty) 'model': model,
    });
    final list = (data is Map ? data['items'] : null) as List? ?? const [];
    return [
      for (final e in list)
        if (e is Map) MonitorCheckItem.fromJson(e.cast<String, dynamic>()),
    ];
  }
}
