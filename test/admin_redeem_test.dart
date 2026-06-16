import 'package:flutter_test/flutter_test.dart';
import 'package:sub2api/src/features/admin/redeem/data/admin_redeem_api.dart';

void main() {
  test('RedeemCode.fromJson', () {
    final c = RedeemCode.fromJson({
      'id': 5,
      'code': 'ABC-123',
      'type': 'subscription',
      'value': 30,
      'status': 'used',
      'used_by': 7,
      'group_id': 2,
      'validity_days': 30,
      'expires_at': '2026-07-01',
    });
    expect(c.code, 'ABC-123');
    expect(c.type, 'subscription');
    expect(c.isUsed, isTrue);
    expect(c.groupId, 2);
    expect(c.validityDays, 30);
  });

  test('RedeemCodePage.fromJson', () {
    final p = RedeemCodePage.fromJson({
      'items': [
        {'id': 1, 'code': 'A'},
        {'id': 2, 'code': 'B'},
      ],
      'total': 2,
      'page': 1,
      'pages': 1,
    });
    expect(p.items.length, 2);
    expect(p.items.first.status, 'unused');
  });

  test('RedeemStats.fromJson 含 by_type', () {
    final s = RedeemStats.fromJson({
      'total_codes': 100,
      'used_codes': 40,
      'expired_codes': 5,
      'by_type': {'balance': 60, 'subscription': 40},
    });
    expect(s.totalCodes, 100);
    expect(s.usedCodes, 40);
    expect(s.byType['balance'], 60);
  });
}
