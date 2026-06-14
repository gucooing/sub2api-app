import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';

/// 上游账号(管理端账号池),取移动端关心的字段子集。
@immutable
class AdminAccount {
  const AdminAccount({
    required this.id,
    required this.name,
    required this.platform,
    required this.type,
    required this.status,
    this.notes,
    this.errorMessage,
    this.concurrency = 0,
    this.currentConcurrency = 0,
    this.priority = 0,
    this.rateMultiplier,
    this.schedulable = true,
    this.lastUsedAt,
    this.expiresAt,
    this.groupNames = const [],
  });

  final int id;
  final String name;
  final String platform; // anthropic / openai / gemini / antigravity
  final String type; // oauth / setup-token / apikey / ...
  final String status; // active / inactive / error
  final String? notes;
  final String? errorMessage;
  final int concurrency;
  final int currentConcurrency;
  final int priority;
  final double? rateMultiplier;
  final bool schedulable;
  final String? lastUsedAt;
  final int? expiresAt; // epoch 秒
  final List<String> groupNames;

  bool get isActive => status == 'active';
  bool get isError => status == 'error';

  factory AdminAccount.fromJson(Map<String, dynamic> json) {
    final groups = <String>[];
    final gs = json['groups'];
    if (gs is List) {
      for (final g in gs) {
        if (g is Map && g['name'] is String) groups.add(g['name'] as String);
      }
    }
    return AdminAccount(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      platform: json['platform'] as String? ?? '',
      type: json['type'] as String? ?? '',
      status: json['status'] as String? ?? 'inactive',
      notes: json['notes'] as String?,
      errorMessage: json['error_message'] as String?,
      concurrency: (json['concurrency'] as num?)?.toInt() ?? 0,
      currentConcurrency: (json['current_concurrency'] as num?)?.toInt() ?? 0,
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      rateMultiplier: (json['rate_multiplier'] as num?)?.toDouble(),
      schedulable: json['schedulable'] as bool? ?? true,
      lastUsedAt: json['last_used_at'] as String?,
      expiresAt: (json['expires_at'] as num?)?.toInt(),
      groupNames: groups,
    );
  }
}

/// 账号池分页结果。
@immutable
class AdminAccountPage {
  const AdminAccountPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pages,
  });

  final List<AdminAccount> items;
  final int total;
  final int page;
  final int pages;

  factory AdminAccountPage.fromJson(Map<String, dynamic> json) {
    final list = json['items'] as List? ?? const [];
    return AdminAccountPage(
      items: list
          .whereType<Map>()
          .map((e) => AdminAccount.fromJson(e.cast<String, dynamic>()))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pages: (json['pages'] as num?)?.toInt() ?? 1,
    );
  }
}

/// 测试账号结果。
@immutable
class AccountTestResult {
  const AccountTestResult(
      {required this.success, required this.message, this.latencyMs});
  final bool success;
  final String message;
  final int? latencyMs;
}

/// 管理端账号池 API。
class AdminAccountsApi {
  AdminAccountsApi(this._client);

  final ApiClient _client;

  Future<AdminAccountPage> list({
    int page = 1,
    int pageSize = 20,
    String? platform,
    String? type,
    String? status,
    String? group,
    String? search,
  }) async {
    final data = await _client.get<dynamic>('/admin/accounts', query: {
      'page': page,
      'page_size': pageSize,
      if (platform != null && platform.isNotEmpty) 'platform': platform,
      if (type != null && type.isNotEmpty) 'type': type,
      if (status != null && status.isNotEmpty) 'status': status,
      if (group != null && group.isNotEmpty) 'group': group,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return AdminAccountPage.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<AdminAccount> getById(int id) async {
    final data = await _client.get<dynamic>('/admin/accounts/$id');
    return AdminAccount.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 今日统计批量(账号 id -> 今日消耗)。
  Future<Map<int, double>> batchTodayCost(List<int> ids) async {
    if (ids.isEmpty) return {};
    final data = await _client.post<dynamic>(
      '/admin/accounts/today-stats/batch',
      data: {'account_ids': ids},
    );
    final stats = ((data as Map)['stats'] as Map?) ?? {};
    final out = <int, double>{};
    stats.forEach((k, v) {
      final id = int.tryParse('$k');
      if (id != null && v is Map) {
        out[id] = (v['cost'] as num?)?.toDouble() ?? 0;
      }
    });
    return out;
  }

  Future<void> setStatus(int id, bool active) =>
      _client.put<dynamic>('/admin/accounts/$id',
          data: {'status': active ? 'active' : 'inactive'});

  Future<void> delete(int id) => _client.delete<dynamic>('/admin/accounts/$id');

  Future<AccountTestResult> test(int id) async {
    final data =
        await _client.post<dynamic>('/admin/accounts/$id/test') as Map;
    return AccountTestResult(
      success: data['success'] as bool? ?? false,
      message: data['message'] as String? ?? '',
      latencyMs: (data['latency_ms'] as num?)?.toInt(),
    );
  }

  Future<void> clearError(int id) =>
      _client.post<dynamic>('/admin/accounts/$id/clear-error');

  Future<void> clearRateLimit(int id) =>
      _client.post<dynamic>('/admin/accounts/$id/clear-rate-limit');

  Future<void> refreshCredentials(int id) =>
      _client.post<dynamic>('/admin/accounts/$id/refresh');
}
