import 'package:flutter_test/flutter_test.dart';
import 'package:sub2api/src/features/admin/accounts/data/account_quota.dart';

void main() {
  group('QuotaLimitValue.applyToExtra', () {
    test('rolling 模式只写额度,不写重置键', () {
      final v = QuotaLimitValue(daily: 10, weekly: 50, total: 100);
      final extra = <String, dynamic>{};
      v.applyToExtra(extra);
      expect(extra['quota_daily_limit'], 10);
      expect(extra['quota_weekly_limit'], 50);
      expect(extra['quota_limit'], 100);
      expect(extra.containsKey('quota_daily_reset_mode'), isFalse);
      expect(extra.containsKey('quota_reset_timezone'), isFalse);
    });

    test('fixed 模式写重置键 + 时区', () {
      final v = QuotaLimitValue(
        daily: 10,
        dailyResetMode: 'fixed',
        dailyResetHour: 3,
        weeklyResetMode: 'fixed',
        weeklyResetDay: 5,
        weeklyResetHour: 9,
        resetTimezone: 'Asia/Shanghai',
      );
      final extra = <String, dynamic>{};
      v.applyToExtra(extra);
      expect(extra['quota_daily_reset_mode'], 'fixed');
      expect(extra['quota_daily_reset_hour'], 3);
      expect(extra['quota_weekly_reset_day'], 5);
      expect(extra['quota_weekly_reset_hour'], 9);
      expect(extra['quota_reset_timezone'], 'Asia/Shanghai');
    });

    test('额度为 0/空 时删除键并清理 used/start', () {
      final extra = <String, dynamic>{
        'quota_daily_limit': 10,
        'quota_daily_used': 3,
        'quota_daily_start': 'x',
      };
      QuotaLimitValue(daily: 0).applyToExtra(extra);
      expect(extra.containsKey('quota_daily_limit'), isFalse);
      expect(extra.containsKey('quota_daily_used'), isFalse);
      expect(extra.containsKey('quota_daily_start'), isFalse);
    });

    test('通知:开启写三键,关闭删除', () {
      final on = QuotaLimitValue(
        total: 100,
        notifyTotal: QuotaNotify(
            enabled: true,
            threshold: 80,
            type: QuotaThresholdType.percentage),
      );
      final extra = <String, dynamic>{};
      on.applyToExtra(extra);
      expect(extra['quota_notify_total_enabled'], true);
      expect(extra['quota_notify_total_threshold'], 80);
      expect(extra['quota_notify_total_threshold_type'], 'percentage');

      final off = <String, dynamic>{
        'quota_notify_total_enabled': true,
        'quota_notify_total_threshold': 80,
        'quota_notify_total_threshold_type': 'percentage',
      };
      QuotaLimitValue(total: 100).applyToExtra(off);
      expect(off.containsKey('quota_notify_total_enabled'), isFalse);
      expect(off.containsKey('quota_notify_total_threshold_type'), isFalse);
    });
  });

  group('AdvancedQuotaValue.applyToExtra', () {
    test('全部启用写对应键', () {
      final v = AdvancedQuotaValue(
        windowCostEnabled: true,
        windowCostLimit: 50,
        windowCostStickyReserve: 8,
        sessionLimitEnabled: true,
        maxSessions: 5,
        sessionIdleTimeout: 12,
        rpmEnabled: true,
        baseRpm: 30,
        rpmStrategy: 'sticky_exempt',
        rpmStickyBuffer: 4,
        userMsgQueueMode: 'throttle',
        tlsEnabled: true,
        tlsProfileId: 7,
        sessionIdMasking: true,
        cacheTtlEnabled: true,
        cacheTtlTarget: '1h',
        customBaseUrlEnabled: true,
        customBaseUrl: 'https://relay.example.com',
      );
      final e = <String, dynamic>{};
      v.applyToExtra(e);
      expect(e['window_cost_limit'], 50);
      expect(e['window_cost_sticky_reserve'], 8);
      expect(e['max_sessions'], 5);
      expect(e['session_idle_timeout_minutes'], 12);
      expect(e['base_rpm'], 30);
      expect(e['rpm_strategy'], 'sticky_exempt');
      expect(e['rpm_sticky_buffer'], 4);
      expect(e['user_msg_queue_mode'], 'throttle');
      expect(e['enable_tls_fingerprint'], true);
      expect(e['tls_fingerprint_profile_id'], 7);
      expect(e['session_id_masking_enabled'], true);
      expect(e['cache_ttl_override_enabled'], true);
      expect(e['cache_ttl_override_target'], '1h');
      expect(e['custom_base_url_enabled'], true);
      expect(e['custom_base_url'], 'https://relay.example.com');
    });

    test('RPM 开启但 baseRpm 缺省时用默认 15;关闭则删除', () {
      final on = AdvancedQuotaValue(rpmEnabled: true);
      final e = <String, dynamic>{};
      on.applyToExtra(e);
      expect(e['base_rpm'], AdvancedQuotaValue.defaultBaseRpm);

      final off = <String, dynamic>{'base_rpm': 30, 'rpm_strategy': 'tiered'};
      AdvancedQuotaValue(rpmEnabled: false).applyToExtra(off);
      expect(off.containsKey('base_rpm'), isFalse);
      expect(off.containsKey('rpm_strategy'), isFalse);
    });
  });
}
