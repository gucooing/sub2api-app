import 'package:flutter_test/flutter_test.dart';
import 'package:sub2api/src/features/admin/affiliates/data/admin_affiliates_api.dart';

void main() {
  test('AffiliateInviteRecord.fromJson', () {
    final r = AffiliateInviteRecord.fromJson({
      'inviter_id': 1,
      'inviter_email': 'a@x.com',
      'inviter_username': 'alice',
      'invitee_id': 2,
      'invitee_email': 'b@x.com',
      'invitee_username': 'bob',
      'aff_code': 'CODE1',
      'total_rebate': 12.5,
      'created_at': '2026-06-01T00:00:00Z',
    });
    expect(r.inviterEmail, 'a@x.com');
    expect(r.inviteeId, 2);
    expect(r.affCode, 'CODE1');
    expect(r.totalRebate, 12.5);
  });

  test('AffiliateRebateRecord.fromJson', () {
    final r = AffiliateRebateRecord.fromJson({
      'order_id': 9,
      'out_trade_no': 'NO9',
      'inviter_id': 1,
      'invitee_id': 2,
      'order_amount': 100,
      'pay_amount': 99,
      'rebate_amount': 5,
      'payment_type': 'alipay',
      'order_status': 'COMPLETED',
      'created_at': '2026-06-02T00:00:00Z',
    });
    expect(r.orderId, 9);
    expect(r.outTradeNo, 'NO9');
    expect(r.rebateAmount, 5);
    expect(r.orderStatus, 'COMPLETED');
  });

  test('AffiliateTransferRecord.fromJson keeps nullable quota snapshots', () {
    final r = AffiliateTransferRecord.fromJson({
      'ledger_id': 3,
      'user_id': 7,
      'user_email': 'u@x.com',
      'username': 'u',
      'amount': 8.8,
      'balance_after': 20,
      'available_quota_after': null,
      'snapshot_available': true,
      'created_at': '2026-06-03T00:00:00Z',
    });
    expect(r.ledgerId, 3);
    expect(r.amount, 8.8);
    expect(r.balanceAfter, 20);
    expect(r.availableQuotaAfter, isNull);
    expect(r.snapshotAvailable, true);
  });

  test('AffiliateUserOverview.fromJson', () {
    final o = AffiliateUserOverview.fromJson({
      'user_id': 7,
      'email': 'u@x.com',
      'username': 'u',
      'aff_code': 'ABC',
      'rebate_rate_percent': 12.5,
      'invited_count': 3,
      'rebated_invitee_count': 2,
      'available_quota': 1.25,
      'history_quota': 9.5,
    });
    expect(o.affCode, 'ABC');
    expect(o.rebateRatePercent, 12.5);
    expect(o.invitedCount, 3);
    expect(o.availableQuota, 1.25);
  });

  test('AffiliateRecordsPage.parse maps items + pagination', () {
    final page = AffiliateRecordsPage.parse({
      'items': [
        {'inviter_id': 1, 'invitee_id': 2, 'aff_code': 'C', 'total_rebate': 1},
        {'inviter_id': 3, 'invitee_id': 4, 'aff_code': 'D', 'total_rebate': 2},
      ],
      'total': 2,
      'page': 1,
      'pages': 1,
    }, AffiliateInviteRecord.fromJson);
    expect(page.items.length, 2);
    expect(page.items.first.affCode, 'C');
    expect(page.total, 2);
    expect(page.pages, 1);
  });
}
