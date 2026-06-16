import 'package:flutter_test/flutter_test.dart';
import 'package:sub2api/src/features/admin/groups/data/admin_groups_api.dart';

void main() {
  test('AdminGroup.fromJson 解析关键字段', () {
    final g = AdminGroup.fromJson({
      'id': 3,
      'name': 'pro',
      'platform': 'anthropic',
      'status': 'inactive',
      'rate_multiplier': 1.5,
      'rpm_limit': 60,
      'is_exclusive': true,
      'claude_code_only': true,
      'daily_limit_usd': 10,
      'account_count': 5,
      'active_account_count': 4,
    });
    expect(g.name, 'pro');
    expect(g.isActive, isFalse);
    expect(g.rateMultiplier, 1.5);
    expect(g.rpmLimit, 60);
    expect(g.isExclusive, isTrue);
    expect(g.claudeCodeOnly, isTrue);
    expect(g.accountCount, 5);
    expect(g.activeAccountCount, 4);
  });

  test('AdminGroup 容忍缺字段', () {
    final g = AdminGroup.fromJson({'id': 1, 'name': 'x'});
    expect(g.status, 'active');
    expect(g.rateMultiplier, 1);
    expect(g.isExclusive, isFalse);
  });

  test('AdminGroupPage.fromJson 分页', () {
    final p = AdminGroupPage.fromJson({
      'items': [
        {'id': 1, 'name': 'a'},
        {'id': 2, 'name': 'b'},
      ],
      'total': 2,
      'page': 1,
      'pages': 1,
    });
    expect(p.items.length, 2);
    expect(p.total, 2);
  });

  test('GroupRateEntry.fromJson', () {
    final e = GroupRateEntry.fromJson({
      'user_id': 9,
      'user_name': 'alice',
      'user_email': 'a@b.com',
      'rate_multiplier': 0.8,
      'rpm_override': 30,
    });
    expect(e.userId, 9);
    expect(e.rateMultiplier, 0.8);
    expect(e.rpmOverride, 30);
  });
}
