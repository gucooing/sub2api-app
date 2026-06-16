import 'package:flutter_test/flutter_test.dart';
import 'package:sub2api/src/features/admin/users/data/admin_users_api.dart';

void main() {
  test('AdminUser.fromJson 解析关键字段', () {
    final u = AdminUser.fromJson({
      'id': 7,
      'username': 'alice',
      'email': 'a@b.com',
      'role': 'admin',
      'status': 'disabled',
      'balance': 12.5,
      'concurrency': 3,
      'current_concurrency': 1,
      'rpm_limit': 60,
      'notes': 'vip',
      'allowed_groups': [1, 2],
      'balance_notify_enabled': true,
      'balance_notify_threshold': 5,
    });
    expect(u.username, 'alice');
    expect(u.isAdmin, isTrue);
    expect(u.isActive, isFalse);
    expect(u.balance, 12.5);
    expect(u.currentConcurrency, 1);
    expect(u.rpmLimit, 60);
    expect(u.allowedGroups, [1, 2]);
    expect(u.balanceNotifyEnabled, isTrue);
  });

  test('AdminUser 容忍缺字段', () {
    final u = AdminUser.fromJson({'id': 1});
    expect(u.role, 'user');
    expect(u.status, 'active');
    expect(u.balance, 0);
    expect(u.allowedGroups, isNull);
  });

  test('AdminUserPage.fromJson 分页解析', () {
    final p = AdminUserPage.fromJson({
      'items': [
        {'id': 1, 'username': 'x'},
        {'id': 2, 'username': 'y'},
      ],
      'total': 2,
      'page': 1,
      'pages': 1,
    });
    expect(p.items.length, 2);
    expect(p.total, 2);
  });

  test('BalanceHistoryPage.fromJson 含 total_recharged', () {
    final h = BalanceHistoryPage.fromJson({
      'items': [
        {'id': 9, 'type': 'admin_balance', 'value': -3, 'notes': 'adjust'},
      ],
      'total': 1,
      'page': 1,
      'pages': 1,
      'total_recharged': 100,
    });
    expect(h.items.first.type, 'admin_balance');
    expect(h.items.first.value, -3);
    expect(h.totalRecharged, 100);
  });
}
