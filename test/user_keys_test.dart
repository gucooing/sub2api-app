import 'package:flutter_test/flutter_test.dart';
import 'package:sub2api/src/features/user/keys/data/keys_api.dart';

void main() {
  test('ApiKeyInfo.fromJson 解析与脱敏', () {
    final key = ApiKeyInfo.fromJson({
      'id': 1,
      'key': 'sk-abcdef1234567890wxyz',
      'name': '测试密钥',
      'status': 'active',
      'group_id': 2,
      'group': {'id': 2, 'name': '默认'},
      'quota': 10.0,
      'quota_used': 2.5,
      'expires_at': '2026-12-31T00:00:00Z',
      'created_at': '2026-06-01T00:00:00Z',
    });

    expect(key.id, 1);
    expect(key.isActive, isTrue);
    expect(key.groupName, '默认');
    expect(key.quota, 10.0);
    expect(key.maskedKey, startsWith('sk-abcd'));
    expect(key.maskedKey, endsWith('wxyz'));
    expect(key.maskedKey.length, lessThan(key.key.length));
    expect(key.expiresAt, isNotNull);
  });

  test('ApiKeyInfo 容忍缺字段;短 key 不脱敏', () {
    final key = ApiKeyInfo.fromJson(const {'id': 7, 'key': 'sk-short'});
    expect(key.name, '');
    expect(key.quota, 0);
    expect(key.maskedKey, 'sk-short');
    expect(key.groupName, isNull);
  });

  test('AvailableGroup.fromJson', () {
    final g = AvailableGroup.fromJson(const {
      'id': 3,
      'name': 'Claude 专属',
      'platform': 'anthropic',
      'rate_multiplier': 1.5,
    });
    expect(g.id, 3);
    expect(g.rateMultiplier, 1.5);
  });
}
