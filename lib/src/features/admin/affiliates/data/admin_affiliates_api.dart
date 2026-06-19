import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';

/// 邀请记录(inviter 邀请 invitee)。
@immutable
class AffiliateInviteRecord {
  const AffiliateInviteRecord({
    required this.inviterId,
    required this.inviterEmail,
    required this.inviterUsername,
    required this.inviteeId,
    required this.inviteeEmail,
    required this.inviteeUsername,
    required this.affCode,
    required this.totalRebate,
    required this.createdAt,
  });

  final int inviterId;
  final String inviterEmail;
  final String inviterUsername;
  final int inviteeId;
  final String inviteeEmail;
  final String inviteeUsername;
  final String affCode;
  final num totalRebate;
  final String createdAt;

  factory AffiliateInviteRecord.fromJson(Map<String, dynamic> j) =>
      AffiliateInviteRecord(
        inviterId: (j['inviter_id'] as num?)?.toInt() ?? 0,
        inviterEmail: j['inviter_email'] as String? ?? '',
        inviterUsername: j['inviter_username'] as String? ?? '',
        inviteeId: (j['invitee_id'] as num?)?.toInt() ?? 0,
        inviteeEmail: j['invitee_email'] as String? ?? '',
        inviteeUsername: j['invitee_username'] as String? ?? '',
        affCode: j['aff_code'] as String? ?? '',
        totalRebate: j['total_rebate'] as num? ?? 0,
        createdAt: j['created_at'] as String? ?? '',
      );
}

/// 返利记录(某订单产生的返利)。
@immutable
class AffiliateRebateRecord {
  const AffiliateRebateRecord({
    required this.orderId,
    required this.outTradeNo,
    required this.inviterId,
    required this.inviterEmail,
    required this.inviterUsername,
    required this.inviteeId,
    required this.inviteeEmail,
    required this.inviteeUsername,
    required this.orderAmount,
    required this.payAmount,
    required this.rebateAmount,
    required this.paymentType,
    required this.orderStatus,
    required this.createdAt,
  });

  final int orderId;
  final String outTradeNo;
  final int inviterId;
  final String inviterEmail;
  final String inviterUsername;
  final int inviteeId;
  final String inviteeEmail;
  final String inviteeUsername;
  final num orderAmount;
  final num payAmount;
  final num rebateAmount;
  final String paymentType;
  final String orderStatus;
  final String createdAt;

  factory AffiliateRebateRecord.fromJson(Map<String, dynamic> j) =>
      AffiliateRebateRecord(
        orderId: (j['order_id'] as num?)?.toInt() ?? 0,
        outTradeNo: j['out_trade_no'] as String? ?? '',
        inviterId: (j['inviter_id'] as num?)?.toInt() ?? 0,
        inviterEmail: j['inviter_email'] as String? ?? '',
        inviterUsername: j['inviter_username'] as String? ?? '',
        inviteeId: (j['invitee_id'] as num?)?.toInt() ?? 0,
        inviteeEmail: j['invitee_email'] as String? ?? '',
        inviteeUsername: j['invitee_username'] as String? ?? '',
        orderAmount: j['order_amount'] as num? ?? 0,
        payAmount: j['pay_amount'] as num? ?? 0,
        rebateAmount: j['rebate_amount'] as num? ?? 0,
        paymentType: j['payment_type'] as String? ?? '',
        orderStatus: j['order_status'] as String? ?? '',
        createdAt: j['created_at'] as String? ?? '',
      );
}

/// 返利转入余额记录(账本)。
@immutable
class AffiliateTransferRecord {
  const AffiliateTransferRecord({
    required this.ledgerId,
    required this.userId,
    required this.userEmail,
    required this.username,
    required this.amount,
    required this.snapshotAvailable,
    required this.createdAt,
    this.balanceAfter,
    this.availableQuotaAfter,
    this.frozenQuotaAfter,
    this.historyQuotaAfter,
  });

  final int ledgerId;
  final int userId;
  final String userEmail;
  final String username;
  final num amount;
  final bool snapshotAvailable;
  final String createdAt;
  final num? balanceAfter;
  final num? availableQuotaAfter;
  final num? frozenQuotaAfter;
  final num? historyQuotaAfter;

  factory AffiliateTransferRecord.fromJson(Map<String, dynamic> j) =>
      AffiliateTransferRecord(
        ledgerId: (j['ledger_id'] as num?)?.toInt() ?? 0,
        userId: (j['user_id'] as num?)?.toInt() ?? 0,
        userEmail: j['user_email'] as String? ?? '',
        username: j['username'] as String? ?? '',
        amount: j['amount'] as num? ?? 0,
        snapshotAvailable: j['snapshot_available'] as bool? ?? false,
        createdAt: j['created_at'] as String? ?? '',
        balanceAfter: j['balance_after'] as num?,
        availableQuotaAfter: j['available_quota_after'] as num?,
        frozenQuotaAfter: j['frozen_quota_after'] as num?,
        historyQuotaAfter: j['history_quota_after'] as num?,
      );
}

/// 用户邀请返利概览(点击记录里的用户弹出)。
@immutable
class AffiliateUserOverview {
  const AffiliateUserOverview({
    required this.userId,
    required this.email,
    required this.username,
    required this.affCode,
    required this.rebateRatePercent,
    required this.invitedCount,
    required this.rebatedInviteeCount,
    required this.availableQuota,
    required this.historyQuota,
  });

  final int userId;
  final String email;
  final String username;
  final String affCode;
  final num rebateRatePercent;
  final int invitedCount;
  final int rebatedInviteeCount;
  final num availableQuota;
  final num historyQuota;

  factory AffiliateUserOverview.fromJson(Map<String, dynamic> j) =>
      AffiliateUserOverview(
        userId: (j['user_id'] as num?)?.toInt() ?? 0,
        email: j['email'] as String? ?? '',
        username: j['username'] as String? ?? '',
        affCode: j['aff_code'] as String? ?? '',
        rebateRatePercent: j['rebate_rate_percent'] as num? ?? 0,
        invitedCount: (j['invited_count'] as num?)?.toInt() ?? 0,
        rebatedInviteeCount: (j['rebated_invitee_count'] as num?)?.toInt() ?? 0,
        availableQuota: j['available_quota'] as num? ?? 0,
        historyQuota: j['history_quota'] as num? ?? 0,
      );
}

/// 通用分页结果(邀请返利记录)。
@immutable
class AffiliateRecordsPage<T> {
  const AffiliateRecordsPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pages,
  });

  final List<T> items;
  final int total;
  final int page;
  final int pages;

  static AffiliateRecordsPage<T> parse<T>(
      dynamic data, T Function(Map<String, dynamic>) fromJson) {
    final json = (data as Map).cast<String, dynamic>();
    final list = json['items'] as List? ?? const [];
    return AffiliateRecordsPage<T>(
      items: list
          .whereType<Map>()
          .map((e) => fromJson(e.cast<String, dynamic>()))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pages: (json['pages'] as num?)?.toInt() ?? 1,
    );
  }
}

/// 管理端邀请返利 API(对照 web api/admin/affiliates.ts)。
class AdminAffiliatesApi {
  AdminAffiliatesApi(this._client);

  final ApiClient _client;

  Map<String, dynamic> _params({
    required int page,
    required int pageSize,
    String? search,
    String? startAt,
    String? endAt,
    String? sortBy,
    String? sortOrder,
  }) =>
      {
        'page': page,
        'page_size': pageSize,
        if (search != null && search.isNotEmpty) 'search': search,
        if (startAt != null && startAt.isNotEmpty) 'start_at': startAt,
        if (endAt != null && endAt.isNotEmpty) 'end_at': endAt,
        if (sortBy != null && sortBy.isNotEmpty) 'sort_by': sortBy,
        if (sortOrder != null && sortOrder.isNotEmpty) 'sort_order': sortOrder,
      };

  Future<AffiliateRecordsPage<AffiliateInviteRecord>> listInvites({
    int page = 1,
    int pageSize = 20,
    String? search,
    String? startAt,
    String? endAt,
    String? sortBy,
    String? sortOrder,
  }) async {
    final data = await _client.get<dynamic>('/admin/affiliates/invites',
        query: _params(
            page: page,
            pageSize: pageSize,
            search: search,
            startAt: startAt,
            endAt: endAt,
            sortBy: sortBy,
            sortOrder: sortOrder));
    return AffiliateRecordsPage.parse(data, AffiliateInviteRecord.fromJson);
  }

  Future<AffiliateRecordsPage<AffiliateRebateRecord>> listRebates({
    int page = 1,
    int pageSize = 20,
    String? search,
    String? startAt,
    String? endAt,
    String? sortBy,
    String? sortOrder,
  }) async {
    final data = await _client.get<dynamic>('/admin/affiliates/rebates',
        query: _params(
            page: page,
            pageSize: pageSize,
            search: search,
            startAt: startAt,
            endAt: endAt,
            sortBy: sortBy,
            sortOrder: sortOrder));
    return AffiliateRecordsPage.parse(data, AffiliateRebateRecord.fromJson);
  }

  Future<AffiliateRecordsPage<AffiliateTransferRecord>> listTransfers({
    int page = 1,
    int pageSize = 20,
    String? search,
    String? startAt,
    String? endAt,
    String? sortBy,
    String? sortOrder,
  }) async {
    final data = await _client.get<dynamic>('/admin/affiliates/transfers',
        query: _params(
            page: page,
            pageSize: pageSize,
            search: search,
            startAt: startAt,
            endAt: endAt,
            sortBy: sortBy,
            sortOrder: sortOrder));
    return AffiliateRecordsPage.parse(data, AffiliateTransferRecord.fromJson);
  }

  Future<AffiliateUserOverview> getUserOverview(int userId) async {
    final data =
        await _client.get<dynamic>('/admin/affiliates/users/$userId/overview');
    return AffiliateUserOverview.fromJson((data as Map).cast<String, dynamic>());
  }
}
