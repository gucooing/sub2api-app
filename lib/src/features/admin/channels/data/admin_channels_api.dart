import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';

/// 渠道某平台的模型定价。价格为 per-token(展示/编辑时换算每百万 token)。
/// 分级区间 intervals 以原始 map 保留(本端暂不编辑,回传时原样保留避免丢失)。
@immutable
class ChannelModelPricing {
  const ChannelModelPricing({
    this.id,
    required this.platform,
    this.models = const [],
    this.billingMode = 'token',
    this.inputPrice,
    this.outputPrice,
    this.cacheWritePrice,
    this.cacheReadPrice,
    this.imageOutputPrice,
    this.perRequestPrice,
    this.intervals = const [],
  });

  final int? id;
  final String platform;
  final List<String> models;
  final String billingMode; // token / per_request / image
  final num? inputPrice;
  final num? outputPrice;
  final num? cacheWritePrice;
  final num? cacheReadPrice;
  final num? imageOutputPrice;
  final num? perRequestPrice;
  final List<Map<String, dynamic>> intervals;

  ChannelModelPricing copyWith({
    String? platform,
    List<String>? models,
    String? billingMode,
    num? inputPrice,
    num? outputPrice,
    num? cacheWritePrice,
    num? cacheReadPrice,
    num? imageOutputPrice,
    num? perRequestPrice,
  }) =>
      ChannelModelPricing(
        id: id,
        platform: platform ?? this.platform,
        models: models ?? this.models,
        billingMode: billingMode ?? this.billingMode,
        inputPrice: inputPrice ?? this.inputPrice,
        outputPrice: outputPrice ?? this.outputPrice,
        cacheWritePrice: cacheWritePrice ?? this.cacheWritePrice,
        cacheReadPrice: cacheReadPrice ?? this.cacheReadPrice,
        imageOutputPrice: imageOutputPrice ?? this.imageOutputPrice,
        perRequestPrice: perRequestPrice ?? this.perRequestPrice,
        intervals: intervals,
      );

  factory ChannelModelPricing.fromJson(Map<String, dynamic> j) =>
      ChannelModelPricing(
        id: (j['id'] as num?)?.toInt(),
        platform: j['platform'] as String? ?? '',
        models: [
          for (final m in (j['models'] as List? ?? const [])) '$m',
        ],
        billingMode: j['billing_mode'] as String? ?? 'token',
        inputPrice: j['input_price'] as num?,
        outputPrice: j['output_price'] as num?,
        cacheWritePrice: j['cache_write_price'] as num?,
        cacheReadPrice: j['cache_read_price'] as num?,
        imageOutputPrice: j['image_output_price'] as num?,
        perRequestPrice: j['per_request_price'] as num?,
        intervals: [
          for (final i in (j['intervals'] as List? ?? const []))
            if (i is Map) i.cast<String, dynamic>(),
        ],
      );

  Map<String, dynamic> toJson() => {
        'id': ?id,
        'platform': platform,
        'models': models,
        'billing_mode': billingMode,
        'input_price': inputPrice,
        'output_price': outputPrice,
        'cache_write_price': cacheWritePrice,
        'cache_read_price': cacheReadPrice,
        'image_output_price': imageOutputPrice,
        'per_request_price': perRequestPrice,
        'intervals': intervals,
      };
}

/// 计费渠道。对照 web Channel。复杂字段(model_mapping/account_stats_pricing_rules/
/// features_config)以 [raw] 原样保留,编辑时回传不丢失。
@immutable
class Channel {
  const Channel({
    required this.id,
    required this.name,
    this.description = '',
    this.status = 'active',
    this.billingModelSource = 'requested',
    this.restrictModels = false,
    this.applyPricingToAccountStats = false,
    this.groupIds = const [],
    this.modelPricing = const [],
    this.raw = const {},
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String name;
  final String description;
  final String status; // active / disabled
  final String billingModelSource; // requested / upstream / channel_mapped
  final bool restrictModels;
  final bool applyPricingToAccountStats;
  final List<int> groupIds;
  final List<ChannelModelPricing> modelPricing;
  final Map<String, dynamic> raw;
  final String? createdAt;
  final String? updatedAt;

  factory Channel.fromJson(Map<String, dynamic> j) => Channel(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: j['name'] as String? ?? '',
        description: j['description'] as String? ?? '',
        status: j['status'] as String? ?? 'active',
        billingModelSource: j['billing_model_source'] as String? ?? 'requested',
        restrictModels: j['restrict_models'] as bool? ?? false,
        applyPricingToAccountStats:
            j['apply_pricing_to_account_stats'] as bool? ?? false,
        groupIds: [
          for (final g in (j['group_ids'] as List? ?? const []))
            if (g is num) g.toInt(),
        ],
        modelPricing: [
          for (final p in (j['model_pricing'] as List? ?? const []))
            if (p is Map)
              ChannelModelPricing.fromJson(p.cast<String, dynamic>()),
        ],
        raw: j,
        createdAt: j['created_at'] as String?,
        updatedAt: j['updated_at'] as String?,
      );
}

@immutable
class ChannelPage {
  const ChannelPage({required this.items, required this.total});

  final List<Channel> items;
  final int total;

  factory ChannelPage.fromJson(Map<String, dynamic> json) {
    final list = json['items'] as List? ?? const [];
    return ChannelPage(
      items: list
          .whereType<Map>()
          .map((e) => Channel.fromJson(e.cast<String, dynamic>()))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 管理端渠道 API(对照 web api/admin/channels.ts)。
class AdminChannelsApi {
  AdminChannelsApi(this._client);

  final ApiClient _client;

  Future<ChannelPage> list({
    int page = 1,
    int pageSize = 20,
    String? status,
    String? search,
    String sortBy = 'created_at',
    String sortOrder = 'desc',
  }) async {
    final data = await _client.get<dynamic>('/admin/channels', query: {
      'page': page,
      'page_size': pageSize,
      if (status != null && status.isNotEmpty) 'status': status,
      if (search != null && search.isNotEmpty) 'search': search,
      'sort_by': sortBy,
      'sort_order': sortOrder,
    });
    return ChannelPage.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<Channel> getById(int id) async {
    final data = await _client.get<dynamic>('/admin/channels/$id');
    return Channel.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<Channel> create(Map<String, dynamic> body) async {
    final data = await _client.post<dynamic>('/admin/channels', data: body);
    return Channel.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<Channel> update(int id, Map<String, dynamic> body) async {
    final data = await _client.put<dynamic>('/admin/channels/$id', data: body);
    return Channel.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<void> delete(int id) => _client.delete<dynamic>('/admin/channels/$id');

  /// 从 LiteLLM 目录拉取某平台最新模型名。
  Future<List<String>> syncPricingModels(String platform) async {
    final data = await _client.get<dynamic>('/admin/channels/pricing/sync-models',
        query: {'platform': platform});
    final models = (data as Map?)?['models'] as List? ?? const [];
    return [for (final m in models) '$m'];
  }
}
