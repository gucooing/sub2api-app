import '../../../../i18n/app_localizations.dart';
import '../../../../shared/widgets/status_pill.dart';
import 'package:flutter/widgets.dart';

/// 订单状态 → 语义色调。
StatusTone orderStatusTone(String status) {
  switch (status.toUpperCase()) {
    case 'COMPLETED':
      return StatusTone.positive;
    case 'PAID':
    case 'RECHARGING':
    case 'REFUND_REQUESTED':
    case 'REFUNDING':
      return StatusTone.info;
    case 'PENDING':
      return StatusTone.warning;
    case 'EXPIRED':
    case 'CANCELLED':
    case 'FAILED':
    case 'REFUND_FAILED':
      return StatusTone.danger;
    default:
      return StatusTone.neutral;
  }
}

/// 订单状态 → 本地化标签。
String orderStatusLabel(BuildContext context, String status) {
  const keys = {
    'PENDING': 'recharge.statusPending',
    'PAID': 'recharge.statusPaid',
    'RECHARGING': 'recharge.statusRecharging',
    'COMPLETED': 'recharge.statusCompleted',
    'EXPIRED': 'recharge.statusExpired',
    'CANCELLED': 'recharge.statusCancelled',
    'FAILED': 'recharge.statusFailed',
    'REFUND_REQUESTED': 'recharge.statusRefundRequested',
    'REFUNDING': 'recharge.statusRefunding',
    'PARTIALLY_REFUNDED': 'recharge.statusPartiallyRefunded',
    'REFUNDED': 'recharge.statusRefunded',
    'REFUND_FAILED': 'recharge.statusRefundFailed',
  };
  final key = keys[status.toUpperCase()];
  return key != null ? context.tr(key) : status;
}

/// 支付方式 → 本地化名称(未知则原样返回)。
String paymentMethodLabel(BuildContext context, String key) {
  const labels = {
    'alipay': 'recharge.methodAlipay',
    'alipay_direct': 'recharge.methodAlipay',
    'wxpay': 'recharge.methodWxpay',
    'wxpay_direct': 'recharge.methodWxpay',
    'stripe': 'recharge.methodStripe',
    'easypay': 'recharge.methodEasypay',
    'airwallex': 'recharge.methodAirwallex',
  };
  final k = labels[key.toLowerCase()];
  return k != null ? context.tr(k) : key;
}
