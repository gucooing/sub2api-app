import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';

// ============ 可用渠道 ============

/// 用户可访问的分组。
@immutable
class AvailableChannelGroup {
  const AvailableChannelGroup({
    required this.id,
    required this.name,
    required this.platform,
    required this.subscriptionType,
    required this.rateMultiplier,
    required this.isExclusive,
  });

  final int id;
  final String name;
  final String platform;

  /// 'standard' | 'subscription'。
  final String subscriptionType;
  final double rateMultiplier;
  final bool isExclusive;

  bool get isSubscription => subscriptionType == 'subscription';

  factory AvailableChannelGroup.fromJson(Map<String, dynamic> json) =>
      AvailableChannelGroup(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        platform: json['platform'] as String? ?? '',
        subscriptionType: json['subscription_type'] as String? ?? 'standard',
        rateMultiplier: (json['rate_multiplier'] as num?)?.toDouble() ?? 1,
        isExclusive: json['is_exclusive'] as bool? ?? false,
      );
}

/// 支持的模型(含定价摘要)。
@immutable
class SupportedModel {
  const SupportedModel({
    required this.name,
    required this.platform,
    this.inputPrice,
    this.outputPrice,
    this.cacheReadPrice,
    this.perRequestPrice,
  });

  final String name;
  final String platform;

  /// 单位与后端一致(通常为每 1M tokens 价格);为空表示未定价。
  final double? inputPrice;
  final double? outputPrice;
  final double? cacheReadPrice;
  final double? perRequestPrice;

  factory SupportedModel.fromJson(Map<String, dynamic> json) {
    final pricing = json['pricing'];
    double? p(String key) =>
        pricing is Map ? (pricing[key] as num?)?.toDouble() : null;
    return SupportedModel(
      name: json['name'] as String? ?? '',
      platform: json['platform'] as String? ?? '',
      inputPrice: p('input_price'),
      outputPrice: p('output_price'),
      cacheReadPrice: p('cache_read_price'),
      perRequestPrice: p('per_request_price'),
    );
  }
}

/// 渠道下单个平台的子视图。
@immutable
class ChannelPlatformSection {
  const ChannelPlatformSection({
    required this.platform,
    required this.groups,
    required this.supportedModels,
  });

  final String platform;
  final List<AvailableChannelGroup> groups;
  final List<SupportedModel> supportedModels;

  factory ChannelPlatformSection.fromJson(Map<String, dynamic> json) =>
      ChannelPlatformSection(
        platform: json['platform'] as String? ?? '',
        groups: (json['groups'] as List?)
                ?.whereType<Map>()
                .map((e) =>
                    AvailableChannelGroup.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
        supportedModels: (json['supported_models'] as List?)
                ?.whereType<Map>()
                .map((e) => SupportedModel.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
      );
}

/// 可用渠道。
@immutable
class AvailableChannel {
  const AvailableChannel({
    required this.name,
    required this.description,
    required this.platforms,
  });

  final String name;
  final String description;
  final List<ChannelPlatformSection> platforms;

  factory AvailableChannel.fromJson(Map<String, dynamic> json) =>
      AvailableChannel(
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        platforms: (json['platforms'] as List?)
                ?.whereType<Map>()
                .map((e) =>
                    ChannelPlatformSection.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
      );
}

// ============ 渠道状态(监控) ============

/// 监控健康度(对齐后端 MonitorStatus)。
enum MonitorStatus { operational, degraded, failed, unknown }

MonitorStatus parseMonitorStatus(String? raw) {
  switch (raw) {
    case 'operational':
      return MonitorStatus.operational;
    case 'degraded':
      return MonitorStatus.degraded;
    case 'failed':
    case 'error':
      return MonitorStatus.failed;
    default:
      return MonitorStatus.unknown;
  }
}

/// 时间轴上的一个监控点。
@immutable
class MonitorTimelinePoint {
  const MonitorTimelinePoint({
    required this.status,
    this.latencyMs,
    this.checkedAt,
  });

  final MonitorStatus status;
  final int? latencyMs;
  final DateTime? checkedAt;

  factory MonitorTimelinePoint.fromJson(Map<String, dynamic> json) =>
      MonitorTimelinePoint(
        status: parseMonitorStatus(json['status'] as String?),
        latencyMs: (json['latency_ms'] as num?)?.toInt(),
        checkedAt: json['checked_at'] != null
            ? DateTime.tryParse(json['checked_at'] as String)?.toLocal()
            : null,
      );
}

/// 监控列表视图(一行 = 一个监控目标)。
@immutable
class MonitorView {
  const MonitorView({
    required this.id,
    required this.name,
    required this.provider,
    required this.groupName,
    required this.primaryModel,
    required this.primaryStatus,
    required this.availability7d,
    this.primaryLatencyMs,
    this.timeline = const [],
  });

  final int id;
  final String name;
  final String provider;
  final String groupName;
  final String primaryModel;
  final MonitorStatus primaryStatus;
  final double availability7d;
  final int? primaryLatencyMs;
  final List<MonitorTimelinePoint> timeline;

  factory MonitorView.fromJson(Map<String, dynamic> json) => MonitorView(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        provider: json['provider'] as String? ?? '',
        groupName: json['group_name'] as String? ?? '',
        primaryModel: json['primary_model'] as String? ?? '',
        primaryStatus: parseMonitorStatus(json['primary_status'] as String?),
        availability7d: (json['availability_7d'] as num?)?.toDouble() ?? 0,
        primaryLatencyMs: (json['primary_latency_ms'] as num?)?.toInt(),
        timeline: (json['timeline'] as List?)
                ?.whereType<Map>()
                .map((e) =>
                    MonitorTimelinePoint.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
      );
}

/// 监控详情中单个模型的多窗口可用率。
@immutable
class MonitorModelDetail {
  const MonitorModelDetail({
    required this.model,
    required this.latestStatus,
    required this.availability7d,
    required this.availability15d,
    required this.availability30d,
    this.latestLatencyMs,
    this.avgLatency7dMs,
  });

  final String model;
  final MonitorStatus latestStatus;
  final double availability7d;
  final double availability15d;
  final double availability30d;
  final int? latestLatencyMs;
  final int? avgLatency7dMs;

  factory MonitorModelDetail.fromJson(Map<String, dynamic> json) =>
      MonitorModelDetail(
        model: json['model'] as String? ?? '',
        latestStatus: parseMonitorStatus(json['latest_status'] as String?),
        availability7d: (json['availability_7d'] as num?)?.toDouble() ?? 0,
        availability15d: (json['availability_15d'] as num?)?.toDouble() ?? 0,
        availability30d: (json['availability_30d'] as num?)?.toDouble() ?? 0,
        latestLatencyMs: (json['latest_latency_ms'] as num?)?.toInt(),
        avgLatency7dMs: (json['avg_latency_7d_ms'] as num?)?.toInt(),
      );
}

/// 监控详情。
@immutable
class MonitorDetail {
  const MonitorDetail({
    required this.id,
    required this.name,
    required this.provider,
    required this.groupName,
    required this.models,
  });

  final int id;
  final String name;
  final String provider;
  final String groupName;
  final List<MonitorModelDetail> models;

  factory MonitorDetail.fromJson(Map<String, dynamic> json) => MonitorDetail(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        provider: json['provider'] as String? ?? '',
        groupName: json['group_name'] as String? ?? '',
        models: (json['models'] as List?)
                ?.whereType<Map>()
                .map((e) =>
                    MonitorModelDetail.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
      );
}

/// 可用渠道 + 渠道状态 API。
class ChannelsApi {
  ChannelsApi(this._client);

  final ApiClient _client;

  /// 当前用户可见的可用渠道。
  Future<List<AvailableChannel>> available() async {
    final data = await _client.get<dynamic>('/channels/available');
    final list = data as List? ?? const [];
    return list
        .whereType<Map>()
        .map((e) => AvailableChannel.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// 渠道监控列表。
  Future<List<MonitorView>> monitors() async {
    final data = await _client.get<dynamic>('/channel-monitors');
    // 兼容 {items:[...]} 或裸数组。
    final list = data is Map ? (data['items'] ?? const []) : (data ?? const []);
    return (list as List)
        .whereType<Map>()
        .map((e) => MonitorView.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// 单个监控的多窗口状态详情。
  Future<MonitorDetail> monitorStatus(int id) async {
    final data = await _client.get<dynamic>('/channel-monitors/$id/status');
    return MonitorDetail.fromJson((data as Map).cast<String, dynamic>());
  }
}
