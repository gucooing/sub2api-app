import 'package:flutter_test/flutter_test.dart';
import 'package:sub2api/src/features/admin/subscriptions/data/admin_subscriptions_api.dart';

void main() {
  test('AdminSubscription.fromJson with embedded user/group limits', () {
    final s = AdminSubscription.fromJson({
      'id': 1,
      'user_id': 7,
      'group_id': 3,
      'status': 'active',
      'daily_usage_usd': 1.5,
      'weekly_usage_usd': 4,
      'monthly_usage_usd': 10,
      'expires_at': '2026-07-01T00:00:00Z',
      'user': {'email': 'a@b.com'},
      'group': {
        'name': 'Pro',
        'platform': 'anthropic',
        'daily_limit_usd': 5,
        'weekly_limit_usd': 20,
        'monthly_limit_usd': 60,
      },
    });
    expect(s.userEmail, 'a@b.com');
    expect(s.groupName, 'Pro');
    expect(s.groupPlatform, 'anthropic');
    expect(s.dailyUsageUsd, 1.5);
    expect(s.dailyLimitUsd, 5);
    expect(s.monthlyLimitUsd, 60);
  });

  test('SubscriptionProgress.fromJson windows', () {
    final p = SubscriptionProgress.fromJson({
      'subscription_id': 1,
      'daily': {'used': 2, 'limit': 5, 'percentage': 40, 'reset_in_seconds': 3600},
      'weekly': null,
      'monthly': {'used': 10, 'limit': null, 'percentage': 0},
      'days_remaining': 12,
      'expires_at': '2026-07-01T00:00:00Z',
    });
    expect(p.daily?.used, 2);
    expect(p.daily?.limit, 5);
    expect(p.daily?.resetInSeconds, 3600);
    expect(p.weekly, isNull);
    expect(p.monthly?.limit, isNull);
    expect(p.daysRemaining, 12);
  });

  test('AdminSubscriptionPage.fromJson', () {
    final pg = AdminSubscriptionPage.fromJson({
      'items': [
        {'id': 1, 'user_id': 1, 'group_id': 1},
        {'id': 2, 'user_id': 2, 'group_id': 1},
      ],
      'total': 2,
      'page': 1,
      'pages': 1,
    });
    expect(pg.items.length, 2);
    expect(pg.items.first.status, 'active');
  });
}
