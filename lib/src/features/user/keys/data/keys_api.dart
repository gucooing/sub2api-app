import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';

/// API 密钥(后端 ApiKey 的客户端裁剪)。
@immutable
class ApiKeyInfo {
  const ApiKeyInfo({
    required this.id,
    required this.key,
    required this.name,
    required this.status,
    this.groupId,
    this.groupName,
    this.rateMultiplier,
    this.quota = 0,
    this.quotaUsed = 0,
    this.usage5h = 0,
    this.usage1d = 0,
    this.usage7d = 0,
    this.rateLimit5h = 0,
    this.rateLimit1d = 0,
    this.rateLimit7d = 0,
    this.expiresAt,
    this.lastUsedAt,
    this.createdAt,
  });

  final int id;

  /// 完整密钥值(列表接口即返回,用于复制)。
  final String key;
  final String name;

  /// active / inactive / quota_exhausted / expired
  final String status;
  final int? groupId;
  final String? groupName;

  /// 分组倍率(group.rate_multiplier),用于「倍率」徽标。
  final double? rateMultiplier;

  /// 配额上限(USD,0 = 不限)。
  final double quota;
  final double quotaUsed;

  /// 滚动窗口已用消耗(USD)。
  final double usage5h;
  final double usage1d;
  final double usage7d;

  /// 滚动窗口消耗上限(USD,0 = 不限)。
  final double rateLimit5h;
  final double rateLimit1d;
  final double rateLimit7d;

  final DateTime? expiresAt;
  final DateTime? lastUsedAt;
  final DateTime? createdAt;

  bool get isActive => status == 'active';

  /// 是否设置了任一滚动窗口限额。
  bool get hasWindowLimits =>
      rateLimit5h > 0 || rateLimit1d > 0 || rateLimit7d > 0;

  /// `sk-abc…wxyz` 形式的脱敏展示。
  String get maskedKey {
    if (key.length <= 12) return key;
    return '${key.substring(0, 7)}…${key.substring(key.length - 4)}';
  }

  factory ApiKeyInfo.fromJson(Map<String, dynamic> json) {
    DateTime? date(String k) => json[k] != null
        ? DateTime.tryParse(json[k] as String)?.toLocal()
        : null;
    double num_(String k) => (json[k] as num?)?.toDouble() ?? 0;
    final group = json['group'];
    return ApiKeyInfo(
      id: (json['id'] as num).toInt(),
      key: json['key'] as String? ?? '',
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
      groupId: (json['group_id'] as num?)?.toInt(),
      groupName: group is Map ? group['name'] as String? : null,
      rateMultiplier:
          group is Map ? (group['rate_multiplier'] as num?)?.toDouble() : null,
      quota: num_('quota'),
      quotaUsed: num_('quota_used'),
      usage5h: num_('usage_5h'),
      usage1d: num_('usage_1d'),
      usage7d: num_('usage_7d'),
      rateLimit5h: num_('rate_limit_5h'),
      rateLimit1d: num_('rate_limit_1d'),
      rateLimit7d: num_('rate_limit_7d'),
      expiresAt: date('expires_at'),
      lastUsedAt: date('last_used_at'),
      createdAt: date('created_at'),
    );
  }
}

/// 用户可绑定的分组(创建/编辑密钥时选择)。
@immutable
class AvailableGroup {
  const AvailableGroup({
    required this.id,
    required this.name,
    this.description,
    this.platform = '',
    this.rateMultiplier = 1,
  });

  final int id;
  final String name;
  final String? description;
  final String platform;
  final double rateMultiplier;

  factory AvailableGroup.fromJson(Map<String, dynamic> json) =>
      AvailableGroup(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String? ?? '',
        description: json['description'] as String?,
        platform: json['platform'] as String? ?? '',
        rateMultiplier: (json['rate_multiplier'] as num?)?.toDouble() ?? 1,
      );
}

class KeysApi {
  KeysApi(this._client);

  final ApiClient _client;

  /// 密钥列表(移动端一次拉取足量,后续需要时再做分页加载)。
  Future<List<ApiKeyInfo>> list({int page = 1, int pageSize = 100}) async {
    final data = await _client.get<dynamic>('/keys', query: {
      'page': page,
      'page_size': pageSize,
    });
    final items = (data as Map)['items'] as List? ?? const [];
    return items
        .whereType<Map>()
        .map((e) => ApiKeyInfo.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<ApiKeyInfo> create({
    required String name,
    int? groupId,
    double? quota,
    int? expiresInDays,
  }) async {
    final data = await _client.post<dynamic>('/keys', data: {
      'name': name,
      'group_id': ?groupId,
      if (quota != null && quota > 0) 'quota': quota,
      if (expiresInDays != null && expiresInDays > 0)
        'expires_in_days': expiresInDays,
    });
    return ApiKeyInfo.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<ApiKeyInfo> update(
    int id, {
    String? name,
    String? status,
    int? groupId,
    double? quota,
  }) async {
    final data = await _client.put<dynamic>('/keys/$id', data: {
      'name': ?name,
      'status': ?status,
      'group_id': ?groupId,
      'quota': ?quota,
    });
    return ApiKeyInfo.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<void> remove(int id) => _client.delete<dynamic>('/keys/$id');

  /// 当前用户可用的分组。
  Future<List<AvailableGroup>> availableGroups() async {
    final data = await _client.get<dynamic>('/groups/available');
    final list = data as List? ?? const [];
    return list
        .whereType<Map>()
        .map((e) => AvailableGroup.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// 批量获取多个密钥的今日/累计消耗(用于列表卡片)。
  /// 返回以密钥 id 为键的映射。
  Future<Map<int, KeyUsageStat>> usageStats(List<int> ids) async {
    if (ids.isEmpty) return const {};
    final data = await _client.post<dynamic>(
      '/usage/dashboard/api-keys-usage',
      data: {'api_key_ids': ids},
    );
    final stats = (data as Map)['stats'];
    final result = <int, KeyUsageStat>{};
    if (stats is Map) {
      stats.forEach((k, v) {
        final id = int.tryParse(k.toString());
        if (id != null && v is Map) {
          result[id] = KeyUsageStat.fromJson(v.cast<String, dynamic>());
        }
      });
    }
    return result;
  }

  /// 单个密钥的每日用量明细(详情页趋势图,默认 30 天)。
  Future<List<ApiKeyDailyPoint>> dailyUsage(int id, {int days = 30}) async {
    final data = await _client.get<dynamic>(
      '/user/api-keys/$id/usage/daily',
      query: {'days': days},
    );
    final items = (data as Map)['items'] as List? ?? const [];
    return items
        .whereType<Map>()
        .map((e) => ApiKeyDailyPoint.fromJson(e.cast<String, dynamic>()))
        .toList();
  }
}

/// 单个密钥的今日/累计消耗(批量接口返回)。
@immutable
class KeyUsageStat {
  const KeyUsageStat({required this.todayActualCost, required this.totalActualCost});

  final double todayActualCost;
  final double totalActualCost;

  factory KeyUsageStat.fromJson(Map<String, dynamic> json) => KeyUsageStat(
        todayActualCost: (json['today_actual_cost'] as num?)?.toDouble() ?? 0,
        totalActualCost: (json['total_actual_cost'] as num?)?.toDouble() ?? 0,
      );
}

/// 密钥每日用量明细点(`/user/api-keys/{id}/usage/daily`)。
@immutable
class ApiKeyDailyPoint {
  const ApiKeyDailyPoint({
    required this.date,
    required this.requests,
    required this.totalTokens,
    required this.actualCost,
  });

  final String date;
  final int requests;
  final int totalTokens;
  final double actualCost;

  /// `2026-06-13` → `06-13`。
  String get shortLabel {
    final parts = date.split('-');
    return parts.length >= 3 ? '${parts[1]}-${parts[2]}' : date;
  }

  factory ApiKeyDailyPoint.fromJson(Map<String, dynamic> json) {
    final cost = (json['cost'] as num?)?.toDouble() ?? 0;
    return ApiKeyDailyPoint(
      date: json['date'] as String? ?? '',
      requests: (json['requests'] as num?)?.toInt() ?? 0,
      totalTokens: (json['total_tokens'] as num?)?.toInt() ?? 0,
      actualCost: (json['actual_cost'] as num?)?.toDouble() ?? cost,
    );
  }
}
