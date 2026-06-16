import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';

/// 兑换码。type: balance / concurrency / subscription / invitation
@immutable
class RedeemCode {
  const RedeemCode({
    required this.id,
    required this.code,
    required this.type,
    required this.value,
    required this.status,
    this.usedBy,
    this.usedAt,
    this.createdAt,
    this.expiresAt,
    this.notes,
    this.groupId,
    this.validityDays,
  });

  final int id;
  final String code;
  final String type;
  final num value;
  final String status; // active / used / expired / unused / disabled
  final int? usedBy;
  final String? usedAt;
  final String? createdAt;
  final String? expiresAt;
  final String? notes;
  final int? groupId;
  final int? validityDays;

  bool get isUsed => status == 'used';

  factory RedeemCode.fromJson(Map<String, dynamic> j) => RedeemCode(
        id: (j['id'] as num?)?.toInt() ?? 0,
        code: j['code'] as String? ?? '',
        type: j['type'] as String? ?? 'balance',
        value: j['value'] as num? ?? 0,
        status: j['status'] as String? ?? 'unused',
        usedBy: (j['used_by'] as num?)?.toInt(),
        usedAt: j['used_at'] as String?,
        createdAt: j['created_at'] as String?,
        expiresAt: j['expires_at'] as String?,
        notes: j['notes'] as String?,
        groupId: (j['group_id'] as num?)?.toInt(),
        validityDays: (j['validity_days'] as num?)?.toInt(),
      );
}

@immutable
class RedeemCodePage {
  const RedeemCodePage({
    required this.items,
    required this.total,
    required this.page,
    required this.pages,
  });

  final List<RedeemCode> items;
  final int total;
  final int page;
  final int pages;

  factory RedeemCodePage.fromJson(Map<String, dynamic> json) {
    final list = json['items'] as List? ?? const [];
    return RedeemCodePage(
      items: list
          .whereType<Map>()
          .map((e) => RedeemCode.fromJson(e.cast<String, dynamic>()))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pages: (json['pages'] as num?)?.toInt() ?? 1,
    );
  }
}

@immutable
class RedeemStats {
  const RedeemStats({
    this.totalCodes = 0,
    this.usedCodes = 0,
    this.expiredCodes = 0,
    this.byType = const {},
  });

  final int totalCodes;
  final int usedCodes;
  final int expiredCodes;
  final Map<String, int> byType;

  factory RedeemStats.fromJson(Map<String, dynamic> j) {
    final bt = <String, int>{};
    final raw = j['by_type'];
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is num) bt['$k'] = v.toInt();
      });
    }
    return RedeemStats(
      totalCodes: (j['total_codes'] as num?)?.toInt() ?? 0,
      usedCodes: (j['used_codes'] as num?)?.toInt() ?? 0,
      expiredCodes: (j['expired_codes'] as num?)?.toInt() ?? 0,
      byType: bt,
    );
  }
}

/// 管理端兑换码 API。
class AdminRedeemApi {
  AdminRedeemApi(this._client);

  final ApiClient _client;

  Future<RedeemCodePage> list({
    int page = 1,
    int pageSize = 20,
    String? type,
    String? status,
    String? search,
  }) async {
    final data = await _client.get<dynamic>('/admin/redeem-codes', query: {
      'page': page,
      'page_size': pageSize,
      if (type != null && type.isNotEmpty) 'type': type,
      if (status != null && status.isNotEmpty) 'status': status,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return RedeemCodePage.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<RedeemStats> stats() async {
    final data = await _client.get<dynamic>('/admin/redeem-codes/stats');
    return RedeemStats.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 批量生成。subscription 需 groupId + validityDays;expiresInDays 为码本身有效期。
  Future<List<RedeemCode>> generate({
    required int count,
    required String type,
    required num value,
    int? groupId,
    int? validityDays,
    int? expiresInDays,
  }) async {
    final payload = <String, dynamic>{
      'count': count,
      'type': type,
      'value': value,
    };
    if (type == 'subscription') {
      payload['group_id'] = groupId;
      if (validityDays != null && validityDays > 0) {
        payload['validity_days'] = validityDays;
      }
    }
    if (expiresInDays != null && expiresInDays > 0) {
      payload['expires_in_days'] = expiresInDays;
    }
    final data =
        await _client.post<dynamic>('/admin/redeem-codes/generate', data: payload);
    final list = (data as List?) ?? const [];
    return [
      for (final e in list)
        if (e is Map) RedeemCode.fromJson(e.cast<String, dynamic>()),
    ];
  }

  Future<void> expire(int id) =>
      _client.post<dynamic>('/admin/redeem-codes/$id/expire');

  Future<void> delete(int id) =>
      _client.delete<dynamic>('/admin/redeem-codes/$id');

  Future<void> batchDelete(List<int> ids) => _client
      .post<dynamic>('/admin/redeem-codes/batch-delete', data: {'ids': ids});
}
