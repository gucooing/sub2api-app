import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';

/// 管理端用户。
@immutable
class AdminUser {
  const AdminUser({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    required this.status,
    this.balance = 0,
    this.concurrency = 0,
    this.currentConcurrency = 0,
    this.rpmLimit,
    this.notes,
    this.avatarUrl,
    this.allowedGroups,
    this.balanceNotifyEnabled = false,
    this.balanceNotifyThreshold,
    this.createdAt,
    this.lastActiveAt,
  });

  final int id;
  final String username;
  final String email;
  final String role; // admin / user
  final String status; // active / disabled
  final num balance;
  final int concurrency;
  final int currentConcurrency;
  final int? rpmLimit;
  final String? notes;
  final String? avatarUrl;
  final List<int>? allowedGroups; // null = 全部非独占分组
  final bool balanceNotifyEnabled;
  final num? balanceNotifyThreshold;
  final String? createdAt;
  final String? lastActiveAt;

  bool get isActive => status == 'active';
  bool get isAdmin => role == 'admin';

  factory AdminUser.fromJson(Map<String, dynamic> j) {
    List<int>? groups;
    final g = j['allowed_groups'];
    if (g is List) {
      groups = [for (final e in g) if (e is num) e.toInt()];
    }
    return AdminUser(
      id: (j['id'] as num?)?.toInt() ?? 0,
      username: j['username'] as String? ?? '',
      email: j['email'] as String? ?? '',
      role: j['role'] as String? ?? 'user',
      status: j['status'] as String? ?? 'active',
      balance: j['balance'] as num? ?? 0,
      concurrency: (j['concurrency'] as num?)?.toInt() ?? 0,
      currentConcurrency: (j['current_concurrency'] as num?)?.toInt() ?? 0,
      rpmLimit: (j['rpm_limit'] as num?)?.toInt(),
      notes: j['notes'] as String?,
      avatarUrl: j['avatar_url'] as String?,
      allowedGroups: groups,
      balanceNotifyEnabled: j['balance_notify_enabled'] as bool? ?? false,
      balanceNotifyThreshold: j['balance_notify_threshold'] as num?,
      createdAt: j['created_at'] as String?,
      lastActiveAt: j['last_active_at'] as String? ?? j['last_used_at'] as String?,
    );
  }
}

/// 用户分页结果。
@immutable
class AdminUserPage {
  const AdminUserPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pages,
  });

  final List<AdminUser> items;
  final int total;
  final int page;
  final int pages;

  factory AdminUserPage.fromJson(Map<String, dynamic> json) {
    final list = json['items'] as List? ?? const [];
    return AdminUserPage(
      items: list
          .whereType<Map>()
          .map((e) => AdminUser.fromJson(e.cast<String, dynamic>()))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pages: (json['pages'] as num?)?.toInt() ?? 1,
    );
  }
}

/// 余额/并发变动历史条目。
@immutable
class BalanceHistoryItem {
  const BalanceHistoryItem({
    required this.id,
    required this.type,
    required this.value,
    this.status,
    this.notes,
    this.createdAt,
  });

  final int id;
  final String type;
  final num value;
  final String? status;
  final String? notes;
  final String? createdAt;

  factory BalanceHistoryItem.fromJson(Map<String, dynamic> j) =>
      BalanceHistoryItem(
        id: (j['id'] as num?)?.toInt() ?? 0,
        type: j['type'] as String? ?? '',
        value: j['value'] as num? ?? 0,
        status: j['status'] as String?,
        notes: j['notes'] as String?,
        createdAt: j['created_at'] as String?,
      );
}

@immutable
class BalanceHistoryPage {
  const BalanceHistoryPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pages,
    this.totalRecharged = 0,
  });

  final List<BalanceHistoryItem> items;
  final int total;
  final int page;
  final int pages;
  final num totalRecharged;

  factory BalanceHistoryPage.fromJson(Map<String, dynamic> json) {
    final list = json['items'] as List? ?? const [];
    return BalanceHistoryPage(
      items: list
          .whereType<Map>()
          .map((e) => BalanceHistoryItem.fromJson(e.cast<String, dynamic>()))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pages: (json['pages'] as num?)?.toInt() ?? 1,
      totalRecharged: json['total_recharged'] as num? ?? 0,
    );
  }
}

/// 管理端用户 API。
class AdminUsersApi {
  AdminUsersApi(this._client);

  final ApiClient _client;

  Future<AdminUserPage> list({
    int page = 1,
    int pageSize = 20,
    String? status,
    String? role,
    String? search,
  }) async {
    final data = await _client.get<dynamic>('/admin/users', query: {
      'page': page,
      'page_size': pageSize,
      if (status != null && status.isNotEmpty) 'status': status,
      if (role != null && role.isNotEmpty) 'role': role,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return AdminUserPage.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<AdminUser> getById(int id) async {
    final data = await _client.get<dynamic>('/admin/users/$id');
    return AdminUser.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<AdminUser> update(int id, Map<String, dynamic> body) async {
    final data = await _client.put<dynamic>('/admin/users/$id', data: body);
    return AdminUser.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<void> setStatus(int id, bool active) =>
      update(id, {'status': active ? 'active' : 'disabled'});

  /// 调整余额:operation = set / add / subtract。
  Future<AdminUser> updateBalance(
    int id, {
    required num balance,
    String operation = 'set',
    String notes = '',
  }) async {
    final data = await _client.post<dynamic>('/admin/users/$id/balance',
        data: {'balance': balance, 'operation': operation, 'notes': notes});
    return AdminUser.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<BalanceHistoryPage> balanceHistory(
    int id, {
    int page = 1,
    int pageSize = 20,
    String? type,
  }) async {
    final data =
        await _client.get<dynamic>('/admin/users/$id/balance-history', query: {
      'page': page,
      'page_size': pageSize,
      if (type != null && type.isNotEmpty) 'type': type,
    });
    return BalanceHistoryPage.fromJson((data as Map).cast<String, dynamic>());
  }
}
