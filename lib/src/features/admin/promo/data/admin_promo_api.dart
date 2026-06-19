import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';

/// 优惠码(注册赠送余额)。对照 web PromoCode。
@immutable
class PromoCode {
  const PromoCode({
    required this.id,
    required this.code,
    required this.bonusAmount,
    required this.maxUses,
    required this.usedCount,
    required this.status,
    this.expiresAt,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String code;
  final num bonusAmount;
  final int maxUses; // 0 = 无限
  final int usedCount;
  final String status; // active / disabled
  final String? expiresAt;
  final String? notes;
  final String? createdAt;
  final String? updatedAt;

  /// 计算有效状态:已过期 / 已用尽 / 启用 / 停用(对照 web getStatusLabel)。
  String effectiveStatus(DateTime now) {
    if (expiresAt != null && expiresAt!.isNotEmpty) {
      final e = DateTime.tryParse(expiresAt!);
      if (e != null && e.isBefore(now)) return 'expired';
    }
    if (maxUses > 0 && usedCount >= maxUses) return 'maxUsed';
    return status == 'active' ? 'active' : 'disabled';
  }

  factory PromoCode.fromJson(Map<String, dynamic> j) => PromoCode(
        id: (j['id'] as num?)?.toInt() ?? 0,
        code: j['code'] as String? ?? '',
        bonusAmount: j['bonus_amount'] as num? ?? 0,
        maxUses: (j['max_uses'] as num?)?.toInt() ?? 0,
        usedCount: (j['used_count'] as num?)?.toInt() ?? 0,
        status: j['status'] as String? ?? 'active',
        expiresAt: j['expires_at'] as String?,
        notes: j['notes'] as String?,
        createdAt: j['created_at'] as String?,
        updatedAt: j['updated_at'] as String?,
      );
}

@immutable
class PromoCodePage {
  const PromoCodePage({
    required this.items,
    required this.total,
    required this.page,
    required this.pages,
  });

  final List<PromoCode> items;
  final int total;
  final int page;
  final int pages;

  factory PromoCodePage.fromJson(Map<String, dynamic> json) {
    final list = json['items'] as List? ?? const [];
    return PromoCodePage(
      items: list
          .whereType<Map>()
          .map((e) => PromoCode.fromJson(e.cast<String, dynamic>()))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pages: (json['pages'] as num?)?.toInt() ?? 1,
    );
  }
}

/// 优惠码使用记录。
@immutable
class PromoCodeUsage {
  const PromoCodeUsage({
    required this.id,
    required this.userId,
    required this.bonusAmount,
    required this.usedAt,
    this.userEmail,
  });

  final int id;
  final int userId;
  final num bonusAmount;
  final String usedAt;
  final String? userEmail;

  factory PromoCodeUsage.fromJson(Map<String, dynamic> j) => PromoCodeUsage(
        id: (j['id'] as num?)?.toInt() ?? 0,
        userId: (j['user_id'] as num?)?.toInt() ?? 0,
        bonusAmount: j['bonus_amount'] as num? ?? 0,
        usedAt: j['used_at'] as String? ?? '',
        userEmail: (j['user'] as Map?)?['email'] as String?,
      );
}

@immutable
class PromoCodeUsagePage {
  const PromoCodeUsagePage({
    required this.items,
    required this.total,
    required this.page,
    required this.pages,
  });

  final List<PromoCodeUsage> items;
  final int total;
  final int page;
  final int pages;

  factory PromoCodeUsagePage.fromJson(Map<String, dynamic> json) {
    final list = json['items'] as List? ?? const [];
    return PromoCodeUsagePage(
      items: list
          .whereType<Map>()
          .map((e) => PromoCodeUsage.fromJson(e.cast<String, dynamic>()))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pages: (json['pages'] as num?)?.toInt() ?? 1,
    );
  }
}

/// 管理端优惠码 API(对照 web api/admin/promo.ts)。
class AdminPromoApi {
  AdminPromoApi(this._client);

  final ApiClient _client;

  Future<PromoCodePage> list({
    int page = 1,
    int pageSize = 20,
    String? status,
    String? search,
    String sortBy = 'created_at',
    String sortOrder = 'desc',
  }) async {
    final data = await _client.get<dynamic>('/admin/promo-codes', query: {
      'page': page,
      'page_size': pageSize,
      if (status != null && status.isNotEmpty) 'status': status,
      if (search != null && search.isNotEmpty) 'search': search,
      'sort_by': sortBy,
      'sort_order': sortOrder,
    });
    return PromoCodePage.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<PromoCode> create({
    String? code,
    required num bonusAmount,
    int? maxUses,
    int? expiresAt, // unix 秒
    String? notes,
  }) async {
    final data = await _client.post<dynamic>('/admin/promo-codes', data: {
      if (code != null && code.isNotEmpty) 'code': code,
      'bonus_amount': bonusAmount,
      'max_uses': ?maxUses,
      'expires_at': ?expiresAt,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return PromoCode.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<PromoCode> update(
    int id, {
    required String code,
    required num bonusAmount,
    required int maxUses,
    required String status,
    int expiresAt = 0, // unix 秒;0 = 清除
    String notes = '',
  }) async {
    final data = await _client.put<dynamic>('/admin/promo-codes/$id', data: {
      'code': code,
      'bonus_amount': bonusAmount,
      'max_uses': maxUses,
      'status': status,
      'expires_at': expiresAt,
      'notes': notes,
    });
    return PromoCode.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<void> delete(int id) =>
      _client.delete<dynamic>('/admin/promo-codes/$id');

  Future<PromoCodeUsagePage> usages(int id,
      {int page = 1, int pageSize = 20}) async {
    final data = await _client.get<dynamic>('/admin/promo-codes/$id/usages',
        query: {'page': page, 'page_size': pageSize});
    return PromoCodeUsagePage.fromJson((data as Map).cast<String, dynamic>());
  }
}
