import 'package:flutter_test/flutter_test.dart';
import 'package:sub2api/src/features/admin/promo/data/admin_promo_api.dart';

void main() {
  test('PromoCode.fromJson', () {
    final c = PromoCode.fromJson({
      'id': 1,
      'code': 'WELCOME',
      'bonus_amount': 5.5,
      'max_uses': 100,
      'used_count': 3,
      'status': 'active',
      'notes': 'hi',
    });
    expect(c.code, 'WELCOME');
    expect(c.bonusAmount, 5.5);
    expect(c.maxUses, 100);
    expect(c.usedCount, 3);
  });

  test('effectiveStatus: active / disabled / maxUsed / expired', () {
    final now = DateTime(2026, 6, 19);
    const active = PromoCode(
        id: 1,
        code: 'A',
        bonusAmount: 1,
        maxUses: 0,
        usedCount: 9,
        status: 'active');
    expect(active.effectiveStatus(now), 'active');

    const disabled = PromoCode(
        id: 1,
        code: 'A',
        bonusAmount: 1,
        maxUses: 0,
        usedCount: 0,
        status: 'disabled');
    expect(disabled.effectiveStatus(now), 'disabled');

    const used = PromoCode(
        id: 1,
        code: 'A',
        bonusAmount: 1,
        maxUses: 5,
        usedCount: 5,
        status: 'active');
    expect(used.effectiveStatus(now), 'maxUsed');

    const expired = PromoCode(
        id: 1,
        code: 'A',
        bonusAmount: 1,
        maxUses: 0,
        usedCount: 0,
        status: 'active',
        expiresAt: '2026-06-01T00:00:00Z');
    expect(expired.effectiveStatus(now), 'expired');
  });

  test('PromoCodeUsage.fromJson extracts user email', () {
    final u = PromoCodeUsage.fromJson({
      'id': 7,
      'user_id': 42,
      'bonus_amount': 2,
      'used_at': '2026-06-10T00:00:00Z',
      'user': {'email': 'x@y.com'},
    });
    expect(u.userId, 42);
    expect(u.userEmail, 'x@y.com');
    expect(u.bonusAmount, 2);
  });

  test('PromoCodePage.fromJson', () {
    final p = PromoCodePage.fromJson({
      'items': [
        {'id': 1, 'code': 'A'},
        {'id': 2, 'code': 'B'},
      ],
      'total': 2,
      'page': 1,
      'pages': 1,
    });
    expect(p.items.length, 2);
    expect(p.items.first.status, 'active');
  });
}
