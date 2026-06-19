import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';

/// 用户订阅(管理员视角)。对照 web UserSubscription(含内嵌 user/group)。
@immutable
class AdminSubscription {
  const AdminSubscription({
    required this.id,
    required this.userId,
    required this.groupId,
    required this.status,
    this.startsAt,
    this.expiresAt,
    this.dailyUsageUsd = 0,
    this.weeklyUsageUsd = 0,
    this.monthlyUsageUsd = 0,
    this.userEmail,
    this.groupName,
    this.groupPlatform,
    this.dailyLimitUsd,
    this.weeklyLimitUsd,
    this.monthlyLimitUsd,
  });

  final int id;
  final int userId;
  final int groupId;
  final String status; // active / expired / revoked
  final String? startsAt;
  final String? expiresAt;
  final num dailyUsageUsd;
  final num weeklyUsageUsd;
  final num monthlyUsageUsd;
  final String? userEmail;
  final String? groupName;
  final String? groupPlatform;
  final num? dailyLimitUsd;
  final num? weeklyLimitUsd;
  final num? monthlyLimitUsd;

  factory AdminSubscription.fromJson(Map<String, dynamic> j) {
    final group = (j['group'] as Map?)?.cast<String, dynamic>();
    return AdminSubscription(
      id: (j['id'] as num?)?.toInt() ?? 0,
      userId: (j['user_id'] as num?)?.toInt() ?? 0,
      groupId: (j['group_id'] as num?)?.toInt() ?? 0,
      status: j['status'] as String? ?? 'active',
      startsAt: j['starts_at'] as String?,
      expiresAt: j['expires_at'] as String?,
      dailyUsageUsd: j['daily_usage_usd'] as num? ?? 0,
      weeklyUsageUsd: j['weekly_usage_usd'] as num? ?? 0,
      monthlyUsageUsd: j['monthly_usage_usd'] as num? ?? 0,
      userEmail: (j['user'] as Map?)?['email'] as String?,
      groupName: group?['name'] as String?,
      groupPlatform: group?['platform'] as String?,
      dailyLimitUsd: group?['daily_limit_usd'] as num?,
      weeklyLimitUsd: group?['weekly_limit_usd'] as num?,
      monthlyLimitUsd: group?['monthly_limit_usd'] as num?,
    );
  }
}

@immutable
class AdminSubscriptionPage {
  const AdminSubscriptionPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pages,
  });

  final List<AdminSubscription> items;
  final int total;
  final int page;
  final int pages;

  factory AdminSubscriptionPage.fromJson(Map<String, dynamic> json) {
    final list = json['items'] as List? ?? const [];
    return AdminSubscriptionPage(
      items: list
          .whereType<Map>()
          .map((e) => AdminSubscription.fromJson(e.cast<String, dynamic>()))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pages: (json['pages'] as num?)?.toInt() ?? 1,
    );
  }
}

/// 单个配额窗口的进度。
@immutable
class SubscriptionWindow {
  const SubscriptionWindow({
    required this.used,
    this.limit,
    this.percentage = 0,
    this.resetInSeconds,
  });

  final num used;
  final num? limit;
  final num percentage;
  final int? resetInSeconds;

  factory SubscriptionWindow.fromJson(Map<String, dynamic> j) =>
      SubscriptionWindow(
        used: j['used'] as num? ?? 0,
        limit: j['limit'] as num?,
        percentage: j['percentage'] as num? ?? 0,
        resetInSeconds: (j['reset_in_seconds'] as num?)?.toInt(),
      );
}

@immutable
class SubscriptionProgress {
  const SubscriptionProgress({
    this.daily,
    this.weekly,
    this.monthly,
    this.expiresAt,
    this.daysRemaining,
  });

  final SubscriptionWindow? daily;
  final SubscriptionWindow? weekly;
  final SubscriptionWindow? monthly;
  final String? expiresAt;
  final int? daysRemaining;

  static SubscriptionWindow? _win(dynamic v) =>
      v is Map ? SubscriptionWindow.fromJson(v.cast<String, dynamic>()) : null;

  factory SubscriptionProgress.fromJson(Map<String, dynamic> j) =>
      SubscriptionProgress(
        daily: _win(j['daily']),
        weekly: _win(j['weekly']),
        monthly: _win(j['monthly']),
        expiresAt: j['expires_at'] as String?,
        daysRemaining: (j['days_remaining'] as num?)?.toInt(),
      );
}

/// 管理端订阅 API(对照 web api/admin/subscriptions.ts)。
class AdminSubscriptionsApi {
  AdminSubscriptionsApi(this._client);

  final ApiClient _client;

  Future<AdminSubscriptionPage> list({
    int page = 1,
    int pageSize = 20,
    String? status,
    int? userId,
    int? groupId,
    String sortBy = 'created_at',
    String sortOrder = 'desc',
  }) async {
    final data = await _client.get<dynamic>('/admin/subscriptions', query: {
      'page': page,
      'page_size': pageSize,
      if (status != null && status.isNotEmpty) 'status': status,
      'user_id': ?userId,
      'group_id': ?groupId,
      'sort_by': sortBy,
      'sort_order': sortOrder,
    });
    return AdminSubscriptionPage.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<SubscriptionProgress> progress(int id) async {
    final data = await _client.get<dynamic>('/admin/subscriptions/$id/progress');
    return SubscriptionProgress.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<void> assign({
    required int userId,
    required int groupId,
    int? validityDays,
  }) =>
      _client.post<dynamic>('/admin/subscriptions/assign', data: {
        'user_id': userId,
        'group_id': groupId,
        'validity_days': ?validityDays,
      });

  Future<void> extend(int id, int days) => _client
      .post<dynamic>('/admin/subscriptions/$id/extend', data: {'days': days});

  Future<void> revoke(int id) =>
      _client.delete<dynamic>('/admin/subscriptions/$id');

  Future<void> resetQuota(
    int id, {
    bool daily = true,
    bool weekly = true,
    bool monthly = true,
  }) =>
      _client.post<dynamic>('/admin/subscriptions/$id/reset-quota',
          data: {'daily': daily, 'weekly': weekly, 'monthly': monthly});

  /// 搜索用户(复用用量端 search-users,返回 id+email,最多 30)。
  Future<List<({int id, String email})>> searchUsers(String q) async {
    final data = await _client
        .get<dynamic>('/admin/usage/search-users', query: {'q': q});
    final list = (data as List?) ?? const [];
    return [
      for (final e in list)
        if (e is Map)
          (
            id: (e['id'] as num?)?.toInt() ?? 0,
            email: e['email'] as String? ?? '',
          ),
    ];
  }
}
