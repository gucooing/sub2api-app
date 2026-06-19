import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';

/// 支付订单(对照 web types/payment.ts PaymentOrder)。
@immutable
class PaymentOrder {
  const PaymentOrder({
    required this.id,
    required this.userId,
    required this.amount,
    required this.payAmount,
    required this.feeRate,
    required this.paymentType,
    required this.outTradeNo,
    required this.status,
    required this.orderType,
    required this.refundAmount,
    this.currency,
    this.createdAt,
    this.expiresAt,
    this.paidAt,
    this.completedAt,
    this.refundReason,
    this.refundRequestedAt,
    this.refundRequestedBy,
    this.refundRequestReason,
    this.planId,
    this.userEmail,
    this.userName,
    this.userNotes,
  });

  final int id;
  final int userId;
  final num amount;
  final num payAmount;
  final num feeRate;
  final String paymentType;
  final String outTradeNo;
  final String status;
  final String orderType; // balance / subscription
  final num refundAmount;
  final String? currency;
  final String? createdAt;
  final String? expiresAt;
  final String? paidAt;
  final String? completedAt;
  final String? refundReason;
  final String? refundRequestedAt;
  final int? refundRequestedBy;
  final String? refundRequestReason;
  final int? planId;
  final String? userEmail;
  final String? userName;
  final String? userNotes;

  /// 充值入账货币符号:balance 订单按 $,订阅按 ¥(对照 web)。
  String get amountSymbol => orderType == 'balance' ? '\$' : '¥';

  /// 实际已退金额:仅 PARTIALLY_REFUNDED / REFUNDED 才是真实退款,
  /// REFUND_REQUESTED 时 refund_amount 是「申请额」而非已退(对照 web AdminRefundDialog)。
  num get actuallyRefunded =>
      (status == 'PARTIALLY_REFUNDED' || status == 'REFUNDED')
          ? refundAmount
          : 0;

  num get maxRefundable => amount - actuallyRefunded;

  factory PaymentOrder.fromJson(Map<String, dynamic> j) => PaymentOrder(
        id: (j['id'] as num?)?.toInt() ?? 0,
        userId: (j['user_id'] as num?)?.toInt() ?? 0,
        amount: j['amount'] as num? ?? 0,
        payAmount: j['pay_amount'] as num? ?? 0,
        feeRate: j['fee_rate'] as num? ?? 0,
        paymentType: j['payment_type'] as String? ?? '',
        outTradeNo: j['out_trade_no'] as String? ?? '',
        status: j['status'] as String? ?? '',
        orderType: j['order_type'] as String? ?? 'balance',
        refundAmount: j['refund_amount'] as num? ?? 0,
        currency: j['currency'] as String?,
        createdAt: j['created_at'] as String?,
        expiresAt: j['expires_at'] as String?,
        paidAt: j['paid_at'] as String?,
        completedAt: j['completed_at'] as String?,
        refundReason: j['refund_reason'] as String?,
        refundRequestedAt: j['refund_requested_at'] as String?,
        refundRequestedBy: (j['refund_requested_by'] as num?)?.toInt(),
        refundRequestReason: j['refund_request_reason'] as String?,
        planId: (j['plan_id'] as num?)?.toInt(),
        userEmail: j['user_email'] as String?,
        userName: j['user_name'] as String?,
        userNotes: j['user_notes'] as String?,
      );
}

/// 订单审计日志(详情接口返回 auditLogs)。
@immutable
class OrderAuditLog {
  const OrderAuditLog({
    required this.id,
    required this.action,
    this.detail,
    this.operator,
    this.createdAt,
  });

  final int id;
  final String action;
  final String? detail;
  final String? operator;
  final String? createdAt;

  factory OrderAuditLog.fromJson(Map<String, dynamic> j) => OrderAuditLog(
        id: (j['id'] as num?)?.toInt() ?? 0,
        action: j['action'] as String? ?? '',
        detail: j['detail'] as String?,
        operator: j['operator'] as String?,
        createdAt: j['created_at'] as String?,
      );
}

/// 订单详情:订单本体 + 审计日志(GET /admin/payment/orders/:id)。
@immutable
class PaymentOrderDetail {
  const PaymentOrderDetail({required this.order, required this.auditLogs});

  final PaymentOrder order;
  final List<OrderAuditLog> auditLogs;
}

@immutable
class PaymentOrderPage {
  const PaymentOrderPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pages,
  });

  final List<PaymentOrder> items;
  final int total;
  final int page;
  final int pages;

  factory PaymentOrderPage.fromJson(Map<String, dynamic> json) {
    final list = json['items'] as List? ?? const [];
    return PaymentOrderPage(
      items: list
          .whereType<Map>()
          .map((e) => PaymentOrder.fromJson(e.cast<String, dynamic>()))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pages: (json['pages'] as num?)?.toInt() ?? 1,
    );
  }
}

// ==================== 支付看板 ====================

@immutable
class DailyRevenuePoint {
  const DailyRevenuePoint(
      {required this.date, required this.amount, required this.count});

  final String date;
  final num amount;
  final int count;

  factory DailyRevenuePoint.fromJson(Map<String, dynamic> j) =>
      DailyRevenuePoint(
        date: j['date'] as String? ?? '',
        amount: j['amount'] as num? ?? 0,
        count: (j['count'] as num?)?.toInt() ?? 0,
      );
}

@immutable
class PaymentMethodStat {
  const PaymentMethodStat(
      {required this.type, required this.amount, required this.count});

  final String type;
  final num amount;
  final int count;

  factory PaymentMethodStat.fromJson(Map<String, dynamic> j) =>
      PaymentMethodStat(
        type: j['type'] as String? ?? '',
        amount: j['amount'] as num? ?? 0,
        count: (j['count'] as num?)?.toInt() ?? 0,
      );
}

@immutable
class TopUserStat {
  const TopUserStat(
      {required this.userId, required this.email, required this.amount});

  final int userId;
  final String email;
  final num amount;

  factory TopUserStat.fromJson(Map<String, dynamic> j) => TopUserStat(
        userId: (j['user_id'] as num?)?.toInt() ?? 0,
        email: j['email'] as String? ?? '',
        amount: j['amount'] as num? ?? 0,
      );
}

@immutable
class PaymentDashboardStats {
  const PaymentDashboardStats({
    required this.todayAmount,
    required this.totalAmount,
    required this.todayCount,
    required this.totalCount,
    required this.avgAmount,
    required this.dailySeries,
    required this.paymentMethods,
    required this.topUsers,
  });

  final num todayAmount;
  final num totalAmount;
  final int todayCount;
  final int totalCount;
  final num avgAmount;
  final List<DailyRevenuePoint> dailySeries;
  final List<PaymentMethodStat> paymentMethods;
  final List<TopUserStat> topUsers;

  factory PaymentDashboardStats.fromJson(Map<String, dynamic> j) =>
      PaymentDashboardStats(
        todayAmount: j['today_amount'] as num? ?? 0,
        totalAmount: j['total_amount'] as num? ?? 0,
        todayCount: (j['today_count'] as num?)?.toInt() ?? 0,
        totalCount: (j['total_count'] as num?)?.toInt() ?? 0,
        avgAmount: j['avg_amount'] as num? ?? 0,
        dailySeries: (j['daily_series'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => DailyRevenuePoint.fromJson(e.cast<String, dynamic>()))
            .toList(),
        paymentMethods: (j['payment_methods'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => PaymentMethodStat.fromJson(e.cast<String, dynamic>()))
            .toList(),
        topUsers: (j['top_users'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => TopUserStat.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );
}

// ==================== 订阅计划 ====================

@immutable
class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.groupId,
    required this.name,
    required this.description,
    required this.price,
    required this.validityDays,
    required this.validityUnit,
    required this.features,
    required this.forSale,
    required this.sortOrder,
    this.originalPrice,
  });

  final int id;
  final int groupId;
  final String name;
  final String description;
  final num price;
  final int validityDays;
  final String validityUnit; // days / weeks / months
  final List<String> features;
  final bool forSale;
  final int sortOrder;
  final num? originalPrice;

  /// 后端 features 以换行分隔的字符串返回,解析为数组(对照 web loadPlans)。
  factory SubscriptionPlan.fromJson(Map<String, dynamic> j) {
    final rawFeatures = j['features'];
    final features = rawFeatures is String
        ? rawFeatures
            .split('\n')
            .map((f) => f.trim())
            .where((f) => f.isNotEmpty)
            .toList()
        : (rawFeatures as List? ?? const [])
            .map((e) => '$e')
            .where((f) => f.isNotEmpty)
            .toList();
    return SubscriptionPlan(
      id: (j['id'] as num?)?.toInt() ?? 0,
      groupId: (j['group_id'] as num?)?.toInt() ?? 0,
      name: j['name'] as String? ?? '',
      description: j['description'] as String? ?? '',
      price: j['price'] as num? ?? 0,
      validityDays: (j['validity_days'] as num?)?.toInt() ?? 0,
      validityUnit: j['validity_unit'] as String? ?? 'days',
      features: features,
      forSale: j['for_sale'] as bool? ?? false,
      sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
      originalPrice: j['original_price'] as num?,
    );
  }
}

/// 管理端支付/订单 API(对照 web api/admin/payment.ts)。
class AdminPaymentApi {
  AdminPaymentApi(this._client);

  final ApiClient _client;

  // ---------- 订单 ----------

  Future<PaymentOrderPage> getOrders({
    int page = 1,
    int pageSize = 20,
    String? status,
    String? paymentType,
    String? orderType,
    String? keyword,
  }) async {
    final data = await _client.get<dynamic>('/admin/payment/orders', query: {
      'page': page,
      'page_size': pageSize,
      if (status != null && status.isNotEmpty) 'status': status,
      if (paymentType != null && paymentType.isNotEmpty)
        'payment_type': paymentType,
      if (orderType != null && orderType.isNotEmpty) 'order_type': orderType,
      if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
    });
    return PaymentOrderPage.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<PaymentOrderDetail> getOrder(int id) async {
    final data = await _client.get<dynamic>('/admin/payment/orders/$id');
    final map = (data as Map).cast<String, dynamic>();
    final orderRaw = (map['order'] as Map?)?.cast<String, dynamic>() ?? map;
    final logs = (map['auditLogs'] ?? map['audit_logs']) as List? ?? const [];
    return PaymentOrderDetail(
      order: PaymentOrder.fromJson(orderRaw),
      auditLogs: logs
          .whereType<Map>()
          .map((e) => OrderAuditLog.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }

  Future<void> cancelOrder(int id) =>
      _client.post<dynamic>('/admin/payment/orders/$id/cancel');

  Future<void> retryRecharge(int id) =>
      _client.post<dynamic>('/admin/payment/orders/$id/retry');

  Future<void> refundOrder(
    int id, {
    required num amount,
    required String reason,
    bool deductBalance = true,
    bool force = false,
  }) =>
      _client.post<dynamic>('/admin/payment/orders/$id/refund', data: {
        'amount': amount,
        'reason': reason,
        'deduct_balance': deductBalance,
        'force': force,
      });

  // ---------- 看板 ----------

  Future<PaymentDashboardStats> getDashboard({int days = 30}) async {
    final data = await _client
        .get<dynamic>('/admin/payment/dashboard', query: {'days': days});
    return PaymentDashboardStats.fromJson((data as Map).cast<String, dynamic>());
  }

  // ---------- 订阅计划 ----------

  Future<List<SubscriptionPlan>> getPlans() async {
    final data = await _client.get<dynamic>('/admin/payment/plans');
    final list = data as List? ?? const [];
    return list
        .whereType<Map>()
        .map((e) => SubscriptionPlan.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<void> createPlan(Map<String, dynamic> data) =>
      _client.post<dynamic>('/admin/payment/plans', data: data);

  Future<void> updatePlan(int id, Map<String, dynamic> data) =>
      _client.put<dynamic>('/admin/payment/plans/$id', data: data);

  Future<void> deletePlan(int id) =>
      _client.delete<dynamic>('/admin/payment/plans/$id');
}
