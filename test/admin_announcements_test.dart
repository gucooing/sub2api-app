import 'package:flutter_test/flutter_test.dart';
import 'package:sub2api/src/features/admin/announcements/data/admin_announcements_api.dart';

void main() {
  test('Announcement.fromJson with targeting', () {
    final a = Announcement.fromJson({
      'id': 3,
      'title': 'Hello',
      'content': 'World',
      'status': 'active',
      'notify_mode': 'popup',
      'starts_at': '2026-06-01T00:00:00Z',
      'targeting': {
        'any_of': [
          {
            'all_of': [
              {'type': 'subscription', 'operator': 'in', 'group_ids': [1, 2]},
              {'type': 'balance', 'operator': 'gte', 'value': 10},
            ]
          }
        ]
      },
    });
    expect(a.title, 'Hello');
    expect(a.notifyMode, 'popup');
    expect(a.targeting.isAll, isFalse);
    expect(a.targeting.anyOf.single.allOf.length, 2);
    expect(a.targeting.anyOf.single.allOf.first.groupIds, [1, 2]);
    expect(a.targeting.anyOf.single.allOf.last.value, 10);
  });

  test('AnnouncementTargeting empty means all', () {
    final t = AnnouncementTargeting.fromJson({'any_of': []});
    expect(t.isAll, isTrue);
    expect(t.toJson(), {'any_of': []});
  });

  test('AnnouncementCondition.toJson omits irrelevant fields per type', () {
    const sub = AnnouncementCondition(
        type: 'subscription', operator: 'in', groupIds: [5]);
    expect(sub.toJson(), {'type': 'subscription', 'operator': 'in', 'group_ids': [5]});

    const bal = AnnouncementCondition(type: 'balance', operator: 'lt', value: 3);
    expect(bal.toJson(), {'type': 'balance', 'operator': 'lt', 'value': 3});
  });

  test('AnnouncementPage.fromJson', () {
    final p = AnnouncementPage.fromJson({
      'items': [
        {'id': 1, 'title': 'A'},
        {'id': 2, 'title': 'B'},
      ],
      'total': 2,
      'page': 1,
      'pages': 1,
    });
    expect(p.items.length, 2);
    expect(p.items.first.status, 'draft');
    expect(p.items.first.targeting.isAll, isTrue);
  });

  test('AnnouncementReadStatus.fromJson', () {
    final r = AnnouncementReadStatus.fromJson({
      'user_id': 9,
      'email': 'a@b.com',
      'username': 'alice',
      'balance': 12.5,
      'eligible': true,
      'read_at': '2026-06-10T00:00:00Z',
    });
    expect(r.email, 'a@b.com');
    expect(r.eligible, isTrue);
    expect(r.balance, 12.5);
    expect(r.readAt, isNotNull);
  });
}
