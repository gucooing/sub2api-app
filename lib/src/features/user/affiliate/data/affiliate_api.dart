import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';

/// 被邀请人。
@immutable
class AffiliateInvitee {
  const AffiliateInvitee({
    required this.userId,
    required this.email,
    required this.username,
    required this.totalRebate,
    this.createdAt,
  });

  final int userId;
  final String email;
  final String username;
  final double totalRebate;
  final DateTime? createdAt;

  factory AffiliateInvitee.fromJson(Map<String, dynamic> json) =>
      AffiliateInvitee(
        userId: (json['user_id'] as num?)?.toInt() ?? 0,
        email: json['email'] as String? ?? '',
        username: json['username'] as String? ?? '',
        totalRebate: (json['total_rebate'] as num?)?.toDouble() ?? 0,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)?.toLocal()
            : null,
      );
}

/// 邀请返利详情。
@immutable
class AffiliateDetail {
  const AffiliateDetail({
    required this.affCode,
    required this.affCount,
    required this.affQuota,
    required this.affFrozenQuota,
    required this.affHistoryQuota,
    required this.rebateRatePercent,
    required this.invitees,
  });

  final String affCode;

  /// 邀请人数。
  final int affCount;

  /// 可转入余额的返利额度。
  final double affQuota;

  /// 冻结中(待结算)的返利额度。
  final double affFrozenQuota;

  /// 历史累计返利。
  final double affHistoryQuota;

  /// 当前生效返利比例(0–100)。
  final double rebateRatePercent;
  final List<AffiliateInvitee> invitees;

  factory AffiliateDetail.fromJson(Map<String, dynamic> json) {
    final inviteesRaw = json['invitees'];
    return AffiliateDetail(
      affCode: json['aff_code'] as String? ?? '',
      affCount: (json['aff_count'] as num?)?.toInt() ?? 0,
      affQuota: (json['aff_quota'] as num?)?.toDouble() ?? 0,
      affFrozenQuota: (json['aff_frozen_quota'] as num?)?.toDouble() ?? 0,
      affHistoryQuota: (json['aff_history_quota'] as num?)?.toDouble() ?? 0,
      rebateRatePercent:
          (json['effective_rebate_rate_percent'] as num?)?.toDouble() ?? 0,
      invitees: inviteesRaw is List
          ? inviteesRaw
              .whereType<Map>()
              .map((e) => AffiliateInvitee.fromJson(e.cast<String, dynamic>()))
              .toList()
          : const [],
    );
  }
}

/// 返利额度转入余额结果。
@immutable
class AffiliateTransferResult {
  const AffiliateTransferResult({
    required this.transferredQuota,
    required this.balance,
  });

  final double transferredQuota;
  final double balance;

  factory AffiliateTransferResult.fromJson(Map<String, dynamic> json) =>
      AffiliateTransferResult(
        transferredQuota: (json['transferred_quota'] as num?)?.toDouble() ?? 0,
        balance: (json['balance'] as num?)?.toDouble() ?? 0,
      );
}

/// 邀请返利 API。
class AffiliateApi {
  AffiliateApi(this._client);

  final ApiClient _client;

  /// 邀请返利详情。
  Future<AffiliateDetail> detail() async {
    final data = await _client.get<dynamic>('/user/aff');
    return AffiliateDetail.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 把返利额度转入账户余额。
  Future<AffiliateTransferResult> transfer() async {
    final data = await _client.post<dynamic>('/user/aff/transfer');
    return AffiliateTransferResult.fromJson(
        (data as Map).cast<String, dynamic>());
  }
}
