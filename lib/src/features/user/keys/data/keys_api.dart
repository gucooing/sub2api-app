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
    this.quota = 0,
    this.quotaUsed = 0,
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

  /// 配额上限(USD,0 = 不限)。
  final double quota;
  final double quotaUsed;
  final DateTime? expiresAt;
  final DateTime? lastUsedAt;
  final DateTime? createdAt;

  bool get isActive => status == 'active';

  /// `sk-abc…wxyz` 形式的脱敏展示。
  String get maskedKey {
    if (key.length <= 12) return key;
    return '${key.substring(0, 7)}…${key.substring(key.length - 4)}';
  }

  factory ApiKeyInfo.fromJson(Map<String, dynamic> json) {
    DateTime? date(String k) => json[k] != null
        ? DateTime.tryParse(json[k] as String)?.toLocal()
        : null;
    final group = json['group'];
    return ApiKeyInfo(
      id: (json['id'] as num).toInt(),
      key: json['key'] as String? ?? '',
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
      groupId: (json['group_id'] as num?)?.toInt(),
      groupName: group is Map ? group['name'] as String? : null,
      quota: (json['quota'] as num?)?.toDouble() ?? 0,
      quotaUsed: (json['quota_used'] as num?)?.toDouble() ?? 0,
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
}
