import 'package:flutter_test/flutter_test.dart';
import 'package:sub2api/src/features/admin/orders/data/admin_payment_api.dart';

void main() {
  test('PaymentOrder.fromJson parses core fields and symbol', () {
    final o = PaymentOrder.fromJson({
      'id': 12,
      'user_id': 7,
      'amount': 50,
      'pay_amount': 49.5,
      'fee_rate': 1,
      'payment_type': 'alipay',
      'out_trade_no': 'NO123',
      'status': 'COMPLETED',
      'order_type': 'balance',
      'refund_amount': 0,
      'created_at': '2026-06-01T00:00:00Z',
    });
    expect(o.id, 12);
    expect(o.userId, 7);
    expect(o.payAmount, 49.5);
    expect(o.amountSymbol, '\$'); // balance -> $
    expect(o.maxRefundable, 50);
    expect(o.actuallyRefunded, 0);
  });

  test('PaymentOrder subscription order uses ¥ symbol', () {
    final o = PaymentOrder.fromJson({
      'id': 1,
      'order_type': 'subscription',
      'amount': 30,
      'pay_amount': 30,
      'status': 'PENDING',
    });
    expect(o.amountSymbol, '¥');
  });

  test('actuallyRefunded only counts real refunds, not requested', () {
    final requested = PaymentOrder.fromJson({
      'id': 1,
      'status': 'REFUND_REQUESTED',
      'amount': 100,
      'refund_amount': 40, // 申请额,不计为已退
    });
    expect(requested.actuallyRefunded, 0);
    expect(requested.maxRefundable, 100);

    final partial = PaymentOrder.fromJson({
      'id': 2,
      'status': 'PARTIALLY_REFUNDED',
      'amount': 100,
      'refund_amount': 40,
    });
    expect(partial.actuallyRefunded, 40);
    expect(partial.maxRefundable, 60);
  });

  test('PaymentOrderPage.fromJson reads pagination', () {
    final p = PaymentOrderPage.fromJson({
      'items': [
        {'id': 1, 'status': 'PAID', 'order_type': 'balance'},
        {'id': 2, 'status': 'PENDING', 'order_type': 'subscription'},
      ],
      'total': 2,
      'page': 1,
      'pages': 1,
    });
    expect(p.items.length, 2);
    expect(p.total, 2);
    expect(p.page, 1);
    expect(p.pages, 1);
  });

  test('SubscriptionPlan.fromJson splits newline feature string', () {
    final plan = SubscriptionPlan.fromJson({
      'id': 3,
      'group_id': 5,
      'name': 'Pro',
      'description': 'desc',
      'price': 9.99,
      'validity_days': 30,
      'validity_unit': 'days',
      'features': 'A\nB\n\n C ',
      'for_sale': true,
      'sort_order': 1,
      'original_price': 19.99,
    });
    expect(plan.features, ['A', 'B', 'C']);
    expect(plan.forSale, true);
    expect(plan.originalPrice, 19.99);
    expect(plan.validityUnit, 'days');
  });

  test('SubscriptionPlan.fromJson accepts array features', () {
    final plan = SubscriptionPlan.fromJson({
      'id': 1,
      'group_id': 1,
      'name': 'X',
      'description': '',
      'price': 1,
      'validity_days': 7,
      'features': ['a', 'b'],
      'for_sale': false,
      'sort_order': 0,
    });
    expect(plan.features, ['a', 'b']);
  });

  test('PaymentDashboardStats.fromJson parses series and breakdowns', () {
    final s = PaymentDashboardStats.fromJson({
      'today_amount': 12.5,
      'total_amount': 100,
      'today_count': 3,
      'total_count': 40,
      'avg_amount': 2.5,
      'daily_series': [
        {'date': '2026-06-01', 'amount': 5, 'count': 1},
        {'date': '2026-06-02', 'amount': 7.5, 'count': 2},
      ],
      'payment_methods': [
        {'type': 'alipay', 'amount': 80, 'count': 30},
      ],
      'top_users': [
        {'user_id': 7, 'email': 'a@b.com', 'amount': 50},
      ],
    });
    expect(s.todayAmount, 12.5);
    expect(s.dailySeries.length, 2);
    expect(s.dailySeries[1].amount, 7.5);
    expect(s.paymentMethods.single.type, 'alipay');
    expect(s.topUsers.single.email, 'a@b.com');
  });
}
