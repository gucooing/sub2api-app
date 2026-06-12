import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';

/// 兑换记录项。
@immutable
class RedeemHistoryItem {
  const RedeemHistoryItem({
    required this.id,
    required this.code,
    required this.type,
    required this.value,
    required this.status,
    this.usedAt,
    this.createdAt,
    this.notes,
    this.groupId,
    this.validityDays,
    this.groupName,
  });

  final int id;
  final String code;
  final String type;
  final double value;
  final String status;
  final DateTime? usedAt;
  final DateTime? createdAt;
  final String? notes;
  final int? groupId;
  final int? validityDays;
  final String? groupName;

  factory RedeemHistoryItem.fromJson(Map<String, dynamic> json) {
    final group = json['group'];
    return RedeemHistoryItem(
      id: (json['id'] as num).toInt(),
      code: json['code'] as String? ?? '',
      type: json['type'] as String? ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? '',
      usedAt: json['used_at'] != null
          ? DateTime.tryParse(json['used_at'] as String)?.toLocal()
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)?.toLocal()
          : null,
      notes: json['notes'] as String?,
      groupId: (json['group_id'] as num?)?.toInt(),
      validityDays: (json['validity_days'] as num?)?.toInt(),
      groupName: group is Map ? group['name'] as String? : null,
    );
  }
}

/// 兑换结果。
@immutable
class RedeemResult {
  const RedeemResult({
    required this.message,
    required this.type,
    required this.value,
    this.newBalance,
    this.newConcurrency,
  });

  final String message;
  final String type;
  final double value;
  final double? newBalance;
  final int? newConcurrency;

  factory RedeemResult.fromJson(Map<String, dynamic> json) => RedeemResult(
        message: json['message'] as String? ?? '',
        type: json['type'] as String? ?? '',
        value: (json['value'] as num?)?.toDouble() ?? 0,
        newBalance: (json['new_balance'] as num?)?.toDouble(),
        newConcurrency: (json['new_concurrency'] as num?)?.toInt(),
      );
}

/// 兑换码 API。
class RedeemApi {
  RedeemApi(this._client);

  final ApiClient _client;

  /// 兑换码兑换。
  Future<RedeemResult> redeem(String code) async {
    final data = await _client.post<dynamic>('/redeem', data: {'code': code});
    return RedeemResult.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 获取兑换历史。
  Future<List<RedeemHistoryItem>> getHistory() async {
    final data = await _client.get<dynamic>('/redeem/history');
    final list = data as List? ?? const [];
    return list
        .whereType<Map>()
        .map((e) => RedeemHistoryItem.fromJson(e.cast<String, dynamic>()))
        .toList();
  }
}

