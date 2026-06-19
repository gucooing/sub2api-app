import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';

/// 管理端分组。
@immutable
class AdminGroup {
  const AdminGroup({
    required this.id,
    required this.name,
    required this.platform,
    required this.status,
    this.description,
    this.rateMultiplier = 1,
    this.rpmLimit,
    this.isExclusive = false,
    this.subscriptionType,
    this.dailyLimitUsd,
    this.weeklyLimitUsd,
    this.monthlyLimitUsd,
    this.claudeCodeOnly = false,
    this.accountCount,
    this.activeAccountCount,
    this.rateLimitedAccountCount,
    this.sortOrder = 0,
  });

  final int id;
  final String name;
  final String platform;
  final String status; // active / inactive
  final String? description;
  final num rateMultiplier;
  final int? rpmLimit;
  final bool isExclusive;
  final String? subscriptionType;
  final num? dailyLimitUsd;
  final num? weeklyLimitUsd;
  final num? monthlyLimitUsd;
  final bool claudeCodeOnly;
  final int? accountCount;
  final int? activeAccountCount;
  final int? rateLimitedAccountCount;
  final int sortOrder;

  bool get isActive => status == 'active';

  factory AdminGroup.fromJson(Map<String, dynamic> j) => AdminGroup(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: j['name'] as String? ?? '',
        platform: j['platform'] as String? ?? '',
        status: j['status'] as String? ?? 'active',
        description: j['description'] as String?,
        rateMultiplier: j['rate_multiplier'] as num? ?? 1,
        rpmLimit: (j['rpm_limit'] as num?)?.toInt(),
        isExclusive: j['is_exclusive'] as bool? ?? false,
        subscriptionType: j['subscription_type'] as String?,
        dailyLimitUsd: j['daily_limit_usd'] as num?,
        weeklyLimitUsd: j['weekly_limit_usd'] as num?,
        monthlyLimitUsd: j['monthly_limit_usd'] as num?,
        claudeCodeOnly: j['claude_code_only'] as bool? ?? false,
        accountCount: (j['account_count'] as num?)?.toInt(),
        activeAccountCount: (j['active_account_count'] as num?)?.toInt(),
        rateLimitedAccountCount:
            (j['rate_limited_account_count'] as num?)?.toInt(),
        sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
      );
}

@immutable
class AdminGroupPage {
  const AdminGroupPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pages,
  });

  final List<AdminGroup> items;
  final int total;
  final int page;
  final int pages;

  factory AdminGroupPage.fromJson(Map<String, dynamic> json) {
    final list = json['items'] as List? ?? const [];
    return AdminGroupPage(
      items: list
          .whereType<Map>()
          .map((e) => AdminGroup.fromJson(e.cast<String, dynamic>()))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pages: (json['pages'] as num?)?.toInt() ?? 1,
    );
  }
}

/// 分组内某用户的专属倍率 / RPM 覆盖。
@immutable
class GroupRateEntry {
  const GroupRateEntry({
    required this.userId,
    required this.userName,
    required this.userEmail,
    this.userStatus,
    this.rateMultiplier,
    this.rpmOverride,
  });

  final int userId;
  final String userName;
  final String userEmail;
  final String? userStatus;
  final num? rateMultiplier;
  final int? rpmOverride;

  factory GroupRateEntry.fromJson(Map<String, dynamic> j) => GroupRateEntry(
        userId: (j['user_id'] as num?)?.toInt() ?? 0,
        userName: j['user_name'] as String? ?? '',
        userEmail: j['user_email'] as String? ?? '',
        userStatus: j['user_status'] as String?,
        rateMultiplier: j['rate_multiplier'] as num?,
        rpmOverride: (j['rpm_override'] as num?)?.toInt(),
      );
}

/// 管理端分组 API。
class AdminGroupsApi {
  AdminGroupsApi(this._client);

  final ApiClient _client;

  Future<AdminGroupPage> list({
    int page = 1,
    int pageSize = 20,
    String? platform,
    String? status,
    String? search,
  }) async {
    final data = await _client.get<dynamic>('/admin/groups', query: {
      'page': page,
      'page_size': pageSize,
      if (platform != null && platform.isNotEmpty) 'platform': platform,
      if (status != null && status.isNotEmpty) 'status': status,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return AdminGroupPage.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<AdminGroup> getById(int id) async {
    final data = await _client.get<dynamic>('/admin/groups/$id');
    return AdminGroup.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 全部分组(完整字段,不分页),供公告定向、订阅等需要 subscription_type 的场景。
  Future<List<AdminGroup>> getAll({bool includeInactive = false}) async {
    final data = await _client.get<dynamic>('/admin/groups/all', query: {
      if (includeInactive) 'include_inactive': true,
    });
    final list = (data as List?) ?? const [];
    return [
      for (final e in list)
        if (e is Map) AdminGroup.fromJson(e.cast<String, dynamic>()),
    ];
  }

  Future<AdminGroup> create(Map<String, dynamic> body) async {
    final data = await _client.post<dynamic>('/admin/groups', data: body);
    return AdminGroup.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<AdminGroup> update(int id, Map<String, dynamic> body) async {
    final data = await _client.put<dynamic>('/admin/groups/$id', data: body);
    return AdminGroup.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<void> setStatus(int id, bool active) =>
      update(id, {'status': active ? 'active' : 'inactive'});

  Future<void> delete(int id) => _client.delete<dynamic>('/admin/groups/$id');

  /// 分组内各用户的专属倍率 / RPM 覆盖。
  Future<List<GroupRateEntry>> rateMultipliers(int id) async {
    final data =
        await _client.get<dynamic>('/admin/groups/$id/rate-multipliers');
    final list = (data as List?) ?? const [];
    return [
      for (final e in list)
        if (e is Map) GroupRateEntry.fromJson(e.cast<String, dynamic>()),
    ];
  }

  /// 批量设置专属倍率(仅动 rate_multiplier 列)。
  Future<void> setRateMultipliers(
          int id, List<({int userId, num rateMultiplier})> entries) =>
      _client.put<dynamic>('/admin/groups/$id/rate-multipliers', data: {
        'entries': [
          for (final e in entries)
            {'user_id': e.userId, 'rate_multiplier': e.rateMultiplier},
        ],
      });

  Future<void> clearRateMultipliers(int id) =>
      _client.delete<dynamic>('/admin/groups/$id/rate-multipliers');

  /// 批量设置 RPM 覆盖(仅动 rpm_override 列)。
  Future<void> setRpmOverrides(
          int id, List<({int userId, int rpmOverride})> entries) =>
      _client.put<dynamic>('/admin/groups/$id/rpm-overrides', data: {
        'entries': [
          for (final e in entries)
            {'user_id': e.userId, 'rpm_override': e.rpmOverride},
        ],
      });

  Future<void> clearRpmOverrides(int id) =>
      _client.delete<dynamic>('/admin/groups/$id/rpm-overrides');
}
