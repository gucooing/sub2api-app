import 'package:flutter_test/flutter_test.dart';
import 'package:sub2api/src/features/admin/accounts/data/admin_accounts_api.dart';

void main() {
  test('AdminAccount.fromJson 解析关键字段与分组名', () {
    final a = AdminAccount.fromJson(const {
      'id': 7,
      'name': 'claude-pool-1',
      'platform': 'anthropic',
      'type': 'oauth',
      'status': 'error',
      'error_message': 'token expired',
      'concurrency': 5,
      'current_concurrency': 2,
      'priority': 10,
      'rate_multiplier': 1.5,
      'schedulable': false,
      'last_used_at': '2026-06-14T08:00:00Z',
      'groups': [
        {'id': 1, 'name': 'default'},
        {'id': 2, 'name': 'pro'},
      ],
    });
    expect(a.id, 7);
    expect(a.platform, 'anthropic');
    expect(a.isError, true);
    expect(a.isActive, false);
    expect(a.currentConcurrency, 2);
    expect(a.rateMultiplier, 1.5);
    expect(a.groupNames, ['default', 'pro']);
  });

  test('AdminAccountPage.fromJson 分页解析', () {
    final p = AdminAccountPage.fromJson(const {
      'items': [
        {'id': 1, 'name': 'a', 'platform': 'openai', 'type': 'apikey', 'status': 'active'},
      ],
      'total': 42,
      'page': 2,
      'pages': 3,
    });
    expect(p.items, hasLength(1));
    expect(p.items.first.isActive, true);
    expect(p.total, 42);
    expect(p.page, 2);
    expect(p.pages, 3);
  });

  test('AdminAccount 容忍缺字段', () {
    final a = AdminAccount.fromJson(const {'id': 1, 'name': 'x'});
    expect(a.status, 'inactive');
    expect(a.groupNames, isEmpty);
    expect(a.rateMultiplier, isNull);
  });
}
