import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';

/// 单种支付方式的限额/费率/可用性。
@immutable
class PaymentMethodLimit {
  const PaymentMethodLimit({
    required this.key,
    required this.dailyLimit,
    required this.dailyUsed,
    required this.dailyRemaining,
    required this.singleMin,
    required this.singleMax,
    required this.feeRate,
    required this.available,
    this.currency,
  });

  final String key;
  final double dailyLimit;
  final double dailyUsed;
  final double dailyRemaining;
  final double singleMin;
  final double singleMax;
  final double feeRate;
  final bool available;
  final String? currency;

  factory PaymentMethodLimit.fromJson(String key, Map<String, dynamic> json) =>
      PaymentMethodLimit(
        key: key,
        dailyLimit: (json['daily_limit'] as num?)?.toDouble() ?? 0,
        dailyUsed: (json['daily_used'] as num?)?.toDouble() ?? 0,
        dailyRemaining: (json['daily_remaining'] as num?)?.toDouble() ?? 0,
        singleMin: (json['single_min'] as num?)?.toDouble() ?? 0,
        singleMax: (json['single_max'] as num?)?.toDouble() ?? 0,
        feeRate: (json['fee_rate'] as num?)?.toDouble() ?? 0,
        available: json['available'] as bool? ?? false,
        currency: json['currency'] as String?,
      );
}

/// 订阅套餐。
@immutable
class PaymentPlan {
  const PaymentPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.originalPrice,
    required this.validityDays,
    this.validityUnit = 'day',
    this.groupName,
    this.rateMultiplier,
    this.features = const [],
    this.forSale = true,
    this.sortOrder = 0,
  });

  final int id;
  final String name;
  final String description;
  final double price;
  final double? originalPrice;
  final int validityDays;
  final String validityUnit;
  final String? groupName;
  final double? rateMultiplier;
  final List<String> features;
  final bool forSale;
  final int sortOrder;

  factory PaymentPlan.fromJson(Map<String, dynamic> json) {
    final rawFeatures = json['features'];
    return PaymentPlan(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      originalPrice: (json['original_price'] as num?)?.toDouble(),
      validityDays: (json['validity_days'] as num?)?.toInt() ?? 0,
      validityUnit: json['validity_unit'] as String? ?? 'day',
      groupName: json['group_name'] as String?,
      rateMultiplier: (json['rate_multiplier'] as num?)?.toDouble(),
      features: rawFeatures is List
          ? rawFeatures.whereType<String>().toList()
          : const [],
      forSale: json['for_sale'] as bool? ?? true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 充值页所需的聚合信息(单次请求)。
@immutable
class CheckoutInfo {
  const CheckoutInfo({
    required this.methods,
    required this.globalMin,
    required this.globalMax,
    required this.plans,
    required this.balanceDisabled,
    required this.balanceRechargeMultiplier,
    required this.rechargeFeeRate,
    this.helpText = '',
    this.helpImageUrl = '',
    this.alipayForceQrcode = false,
  });

  /// 可用支付方式(已过滤 available=true,保持后端顺序)。
  final List<PaymentMethodLimit> methods;
  final double globalMin;
  final double globalMax;
  final List<PaymentPlan> plans;
  final bool balanceDisabled;
  final double balanceRechargeMultiplier;
  final double rechargeFeeRate;
  final String helpText;
  final String helpImageUrl;
  final bool alipayForceQrcode;

  factory CheckoutInfo.fromJson(Map<String, dynamic> json) {
    final methodsRaw = json['methods'];
    final methods = <PaymentMethodLimit>[];
    if (methodsRaw is Map) {
      methodsRaw.forEach((key, value) {
        if (value is Map) {
          methods.add(PaymentMethodLimit.fromJson(
              key as String, value.cast<String, dynamic>()));
        }
      });
    }
    final plansRaw = json['plans'];
    final plans = plansRaw is List
        ? plansRaw
            .whereType<Map>()
            .map((e) => PaymentPlan.fromJson(e.cast<String, dynamic>()))
            .where((p) => p.forSale)
            .toList()
        : <PaymentPlan>[];
    plans.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return CheckoutInfo(
      methods: methods.where((m) => m.available).toList(),
      globalMin: (json['global_min'] as num?)?.toDouble() ?? 0,
      globalMax: (json['global_max'] as num?)?.toDouble() ?? 0,
      plans: plans,
      balanceDisabled: json['balance_disabled'] as bool? ?? false,
      balanceRechargeMultiplier:
          (json['balance_recharge_multiplier'] as num?)?.toDouble() ?? 1,
      rechargeFeeRate: (json['recharge_fee_rate'] as num?)?.toDouble() ?? 0,
      helpText: json['help_text'] as String? ?? '',
      helpImageUrl: json['help_image_url'] as String? ?? '',
      alipayForceQrcode: json['alipay_force_qrcode'] as bool? ?? false,
    );
  }
}

/// 下单结果。
@immutable
class CreateOrderResult {
  const CreateOrderResult({
    required this.orderId,
    required this.amount,
    required this.payAmount,
    this.resultType,
    this.payUrl,
    this.qrCode,
    this.outTradeNo,
    this.expiresAt,
  });

  final int orderId;
  final double amount;
  final double payAmount;

  /// 'order_created' | 'oauth_required' | 'jsapi_ready'
  final String? resultType;
  final String? payUrl;
  final String? qrCode;
  final String? outTradeNo;
  final DateTime? expiresAt;

  factory CreateOrderResult.fromJson(Map<String, dynamic> json) =>
      CreateOrderResult(
        orderId: (json['order_id'] as num?)?.toInt() ?? 0,
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        payAmount: (json['pay_amount'] as num?)?.toDouble() ?? 0,
        resultType: json['result_type'] as String?,
        payUrl: json['pay_url'] as String?,
        qrCode: json['qr_code'] as String?,
        outTradeNo: json['out_trade_no'] as String?,
        expiresAt: json['expires_at'] != null
            ? DateTime.tryParse(json['expires_at'] as String)?.toLocal()
            : null,
      );
}

/// 支付订单。
@immutable
class PaymentOrder {
  const PaymentOrder({
    required this.id,
    required this.amount,
    required this.payAmount,
    required this.paymentType,
    required this.outTradeNo,
    required this.status,
    required this.orderType,
    this.currency,
    this.createdAt,
    this.expiresAt,
    this.paidAt,
  });

  final int id;
  final double amount;
  final double payAmount;
  final String paymentType;
  final String outTradeNo;
  final String status;
  final String orderType;
  final String? currency;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final DateTime? paidAt;

  factory PaymentOrder.fromJson(Map<String, dynamic> json) => PaymentOrder(
        id: (json['id'] as num?)?.toInt() ?? 0,
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        payAmount: (json['pay_amount'] as num?)?.toDouble() ?? 0,
        paymentType: json['payment_type'] as String? ?? '',
        outTradeNo: json['out_trade_no'] as String? ?? '',
        status: json['status'] as String? ?? '',
        orderType: json['order_type'] as String? ?? 'balance',
        currency: json['currency'] as String?,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)?.toLocal()
            : null,
        expiresAt: json['expires_at'] != null
            ? DateTime.tryParse(json['expires_at'] as String)?.toLocal()
            : null,
        paidAt: json['paid_at'] != null
            ? DateTime.tryParse(json['paid_at'] as String)?.toLocal()
            : null,
      );
}

/// 充值 / 支付 API。
class RechargeApi {
  RechargeApi(this._client);

  final ApiClient _client;

  /// 充值页聚合信息。
  Future<CheckoutInfo> checkoutInfo() async {
    final data = await _client.get<dynamic>('/payment/checkout-info');
    return CheckoutInfo.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 创建订单。[orderType] = 'balance' | 'subscription'。
  Future<CreateOrderResult> createOrder({
    required double amount,
    required String paymentType,
    String orderType = 'balance',
    int? planId,
    bool isMobile = true,
  }) async {
    final data = await _client.post<dynamic>('/payment/orders', data: {
      'amount': amount,
      'payment_type': paymentType,
      'order_type': orderType,
      'plan_id': ?planId,
      'is_mobile': isMobile,
    });
    return CreateOrderResult.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 我的订单(分页)。
  Future<List<PaymentOrder>> myOrders({int page = 1, int pageSize = 20}) async {
    final data = await _client.get<dynamic>(
      '/payment/orders/my',
      query: {'page': page, 'page_size': pageSize},
    );
    // 兼容分页包 {items/list/data,total} 或裸数组。
    final list = data is Map
        ? (data['items'] ?? data['list'] ?? data['data'] ?? const [])
        : (data ?? const []);
    return (list as List)
        .whereType<Map>()
        .map((e) => PaymentOrder.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// 手动核验订单支付状态。
  Future<PaymentOrder> verifyOrder(String outTradeNo) async {
    final data = await _client.post<dynamic>(
      '/payment/orders/verify',
      data: {'out_trade_no': outTradeNo},
    );
    return PaymentOrder.fromJson((data as Map).cast<String, dynamic>());
  }
}
