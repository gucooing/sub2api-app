import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';

/// 用户订阅。
@immutable
class UserSubscription {
  const UserSubscription({
    required this.id,
    required this.userId,
    required this.groupId,
    required this.groupName,
    required this.status,
    this.startedAt,
    this.expiresAt,
    this.daysRemaining,
  });

  final int id;
  final int userId;
  final int groupId;
  final String groupName;
  final String status;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final int? daysRemaining;

  factory UserSubscription.fromJson(Map<String, dynamic> json) {
    final group = json['group'];
    return UserSubscription(
      id: (json['id'] as num).toInt(),
      userId: (json['user_id'] as num).toInt(),
      groupId: (json['group_id'] as num).toInt(),
      groupName: group is Map ? group['name'] as String? ?? '' : '',
      status: json['status'] as String? ?? '',
      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'] as String)?.toLocal()
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)?.toLocal()
          : null,
      daysRemaining: (json['days_remaining'] as num?)?.toInt(),
    );
  }
}

/// 订阅进度。
@immutable
class SubscriptionProgress {
  const SubscriptionProgress({
    required this.subscriptionId,
    this.dailyLimit,
    this.dailyUsed,
    this.weeklyLimit,
    this.weeklyUsed,
    this.monthlyLimit,
    this.monthlyUsed,
  });

  final int subscriptionId;
  final double? dailyLimit;
  final double? dailyUsed;
  final double? weeklyLimit;
  final double? weeklyUsed;
  final double? monthlyLimit;
  final double? monthlyUsed;

  factory SubscriptionProgress.fromJson(Map<String, dynamic> json) =>
      SubscriptionProgress(
        subscriptionId: (json['subscription_id'] as num).toInt(),
        dailyLimit: (json['daily_limit'] as num?)?.toDouble(),
        dailyUsed: (json['daily_used'] as num?)?.toDouble(),
        weeklyLimit: (json['weekly_limit'] as num?)?.toDouble(),
        weeklyUsed: (json['weekly_used'] as num?)?.toDouble(),
        monthlyLimit: (json['monthly_limit'] as num?)?.toDouble(),
        monthlyUsed: (json['monthly_used'] as num?)?.toDouble(),
      );
}

/// 订阅 API。
class SubscriptionsApi {
  SubscriptionsApi(this._client);

  final ApiClient _client;

  /// 获取我的订阅列表。
  Future<List<UserSubscription>> getMySubscriptions() async {
    final data = await _client.get<dynamic>('/subscriptions');
    final list = data as List? ?? const [];
    return list
        .whereType<Map>()
        .map((e) => UserSubscription.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// 获取订阅进度。
  Future<List<SubscriptionProgress>> getProgress() async {
    final data = await _client.get<dynamic>('/subscriptions/progress');
    final list = data as List? ?? const [];
    return list
        .whereType<Map>()
        .map((e) => SubscriptionProgress.fromJson(e.cast<String, dynamic>()))
        .toList();
  }
}
