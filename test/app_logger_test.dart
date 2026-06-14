import 'package:flutter_test/flutter_test.dart';
import 'package:sub2api/src/core/logging/app_logger.dart';

void main() {
  group('AppLogger.redact 脱敏', () {
    test('Bearer 令牌脱敏', () {
      expect(
        AppLogger.redact('Authorization: Bearer abc123.def-456_GHI'),
        contains('Bearer ***'),
      );
      expect(
        AppLogger.redact('Bearer abc123.def-456_GHI'),
        isNot(contains('abc123')),
      );
    });

    test('JSON 敏感字段值脱敏', () {
      final s = AppLogger.redact(
          '{"access_token":"eyJxxx","password":"p@ss","other":"keep"}');
      expect(s, isNot(contains('eyJxxx')));
      expect(s, isNot(contains('p@ss')));
      expect(s, contains('keep')); // 非敏感字段保留
    });

    test('sk- 形式密钥脱敏', () {
      expect(
        AppLogger.redact('key=sk-abcDEF123456ghancx'),
        contains('sk-***'),
      );
    });

    test('邮箱保留首字符与域名', () {
      final s = AppLogger.redact('user test@example.com failed');
      expect(s, contains('@example.com'));
      expect(s, isNot(contains('test@example.com')));
      expect(s, contains('t***@example.com'));
    });

    test('LogEntry JSON 往返', () {
      final e = LogEntry(
          time: DateTime.utc(2026, 6, 14, 8, 30),
          level: 'error',
          message: 'boom');
      final round = LogEntry.fromJson(e.toJson());
      expect(round.level, 'error');
      expect(round.message, 'boom');
      expect(round.time, DateTime.utc(2026, 6, 14, 8, 30));
    });
  });
}
