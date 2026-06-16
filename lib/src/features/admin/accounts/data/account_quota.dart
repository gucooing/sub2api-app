import 'admin_accounts_api.dart';

/// 配额阈值通知类型。
enum QuotaThresholdType { fixed, percentage }

String quotaThresholdTypeToString(QuotaThresholdType t) =>
    t == QuotaThresholdType.percentage ? 'percentage' : 'fixed';

QuotaThresholdType quotaThresholdTypeFromString(String? s) =>
    s == 'percentage' ? QuotaThresholdType.percentage : QuotaThresholdType.fixed;

/// 单维度(日/周/总)的通知配置。
class QuotaNotify {
  QuotaNotify({
    this.enabled = false,
    this.threshold,
    this.type = QuotaThresholdType.fixed,
  });
  bool enabled;
  num? threshold;
  QuotaThresholdType type;
}

/// 配额控制(总/日/周额度 + 重置 + 通知)。适用 apikey / bedrock。
/// 全部落在账号 `extra` 上,键名对照 web `EditAccountModal` + `useQuotaNotifyState`。
class QuotaLimitValue {
  QuotaLimitValue({
    this.total,
    this.daily,
    this.weekly,
    this.dailyResetMode = 'rolling',
    this.dailyResetHour = 0,
    this.weeklyResetMode = 'rolling',
    this.weeklyResetDay = 1,
    this.weeklyResetHour = 0,
    this.resetTimezone = 'UTC',
    QuotaNotify? notifyDaily,
    QuotaNotify? notifyWeekly,
    QuotaNotify? notifyTotal,
  })  : notifyDaily = notifyDaily ?? QuotaNotify(),
        notifyWeekly = notifyWeekly ?? QuotaNotify(),
        notifyTotal = notifyTotal ?? QuotaNotify();

  num? total;
  num? daily;
  num? weekly;
  String dailyResetMode; // rolling / fixed
  int dailyResetHour;
  String weeklyResetMode; // rolling / fixed
  int weeklyResetDay; // 0=周日..6=周六
  int weeklyResetHour;
  String resetTimezone;
  QuotaNotify notifyDaily;
  QuotaNotify notifyWeekly;
  QuotaNotify notifyTotal;

  /// 任一额度 > 0 即视为「已启用」。
  bool get enabled =>
      (total ?? 0) > 0 || (daily ?? 0) > 0 || (weekly ?? 0) > 0;

  factory QuotaLimitValue.fromAccount(AdminAccount a) {
    final e = a.extra;
    QuotaNotify notify(String dim) => QuotaNotify(
          enabled: e['quota_notify_${dim}_enabled'] == true,
          threshold: e['quota_notify_${dim}_threshold'] as num?,
          type: quotaThresholdTypeFromString(
              e['quota_notify_${dim}_threshold_type'] as String?),
        );
    num? pos(num? v) => (v != null && v > 0) ? v : null;
    return QuotaLimitValue(
      total: pos(a.quotaLimit),
      daily: pos(a.quotaDailyLimit),
      weekly: pos(a.quotaWeeklyLimit),
      dailyResetMode: a.quotaDailyResetMode ?? 'rolling',
      dailyResetHour: a.quotaDailyResetHour ?? 0,
      weeklyResetMode: a.quotaWeeklyResetMode ?? 'rolling',
      weeklyResetDay: a.quotaWeeklyResetDay ?? 1,
      weeklyResetHour: a.quotaWeeklyResetHour ?? 0,
      resetTimezone: a.quotaResetTimezone ?? 'UTC',
      notifyDaily: notify('daily'),
      notifyWeekly: notify('weekly'),
      notifyTotal: notify('total'),
    );
  }

  /// 写入 extra(改/删键,update 语义)。
  void applyToExtra(Map<String, dynamic> extra) {
    void limit(String key, num? v, {List<String> alsoClear = const []}) {
      if (v != null && v > 0) {
        extra[key] = v;
      } else {
        extra.remove(key);
        for (final k in alsoClear) {
          extra.remove(k);
        }
      }
    }

    limit('quota_limit', total);
    limit('quota_daily_limit', daily,
        alsoClear: ['quota_daily_used', 'quota_daily_start']);
    limit('quota_weekly_limit', weekly,
        alsoClear: ['quota_weekly_used', 'quota_weekly_start']);

    if (dailyResetMode == 'fixed') {
      extra['quota_daily_reset_mode'] = 'fixed';
      extra['quota_daily_reset_hour'] = dailyResetHour;
    } else {
      extra
        ..remove('quota_daily_reset_mode')
        ..remove('quota_daily_reset_hour');
    }
    if (weeklyResetMode == 'fixed') {
      extra['quota_weekly_reset_mode'] = 'fixed';
      extra['quota_weekly_reset_day'] = weeklyResetDay;
      extra['quota_weekly_reset_hour'] = weeklyResetHour;
    } else {
      extra
        ..remove('quota_weekly_reset_mode')
        ..remove('quota_weekly_reset_day')
        ..remove('quota_weekly_reset_hour');
    }
    if (dailyResetMode == 'fixed' || weeklyResetMode == 'fixed') {
      extra['quota_reset_timezone'] =
          resetTimezone.isEmpty ? 'UTC' : resetTimezone;
    } else {
      extra.remove('quota_reset_timezone');
    }

    void notify(String dim, QuotaNotify n) {
      if (n.enabled) {
        extra['quota_notify_${dim}_enabled'] = true;
        if (n.threshold != null) {
          extra['quota_notify_${dim}_threshold'] = n.threshold;
        } else {
          extra.remove('quota_notify_${dim}_threshold');
        }
        extra['quota_notify_${dim}_threshold_type'] =
            quotaThresholdTypeToString(n.type);
      } else {
        extra
          ..remove('quota_notify_${dim}_enabled')
          ..remove('quota_notify_${dim}_threshold')
          ..remove('quota_notify_${dim}_threshold_type');
      }
    }

    notify('daily', notifyDaily);
    notify('weekly', notifyWeekly);
    notify('total', notifyTotal);
  }

  /// 关闭整卡时清空全部额度与重置/通知键。
  void clearInto(Map<String, dynamic> extra) {
    total = daily = weekly = null;
    dailyResetMode = weeklyResetMode = 'rolling';
    notifyDaily = QuotaNotify();
    notifyWeekly = QuotaNotify();
    notifyTotal = QuotaNotify();
    applyToExtra(extra);
  }
}

/// 高级配额控制(Anthropic OAuth / setup-token):窗口费用 / 会话 / RPM / UMQ /
/// TLS 指纹 / 会话ID掩码 / 缓存TTL / 自定义 BaseURL。全部落在 `extra`。
class AdvancedQuotaValue {
  AdvancedQuotaValue({
    this.windowCostEnabled = false,
    this.windowCostLimit,
    this.windowCostStickyReserve,
    this.sessionLimitEnabled = false,
    this.maxSessions,
    this.sessionIdleTimeout,
    this.rpmEnabled = false,
    this.baseRpm,
    this.rpmStrategy = 'tiered',
    this.rpmStickyBuffer,
    this.userMsgQueueMode = '',
    this.tlsEnabled = false,
    this.tlsProfileId,
    this.sessionIdMasking = false,
    this.cacheTtlEnabled = false,
    this.cacheTtlTarget = '5m',
    this.customBaseUrlEnabled = false,
    this.customBaseUrl = '',
  });

  bool windowCostEnabled;
  num? windowCostLimit;
  num? windowCostStickyReserve;
  bool sessionLimitEnabled;
  int? maxSessions;
  int? sessionIdleTimeout;
  bool rpmEnabled;
  int? baseRpm;
  String rpmStrategy; // tiered / sticky_exempt
  int? rpmStickyBuffer;
  String userMsgQueueMode; // '' / throttle / serialize
  bool tlsEnabled;
  int? tlsProfileId; // null=默认, -1=随机
  bool sessionIdMasking;
  bool cacheTtlEnabled;
  String cacheTtlTarget; // 5m / 1h
  bool customBaseUrlEnabled;
  String customBaseUrl;

  static const int defaultBaseRpm = 15;

  factory AdvancedQuotaValue.fromAccount(AdminAccount a) {
    return AdvancedQuotaValue(
      windowCostEnabled: (a.windowCostLimit ?? 0) > 0,
      windowCostLimit: (a.windowCostLimit ?? 0) > 0 ? a.windowCostLimit : null,
      windowCostStickyReserve:
          (a.windowCostLimit ?? 0) > 0 ? (a.windowCostStickyReserve ?? 10) : null,
      sessionLimitEnabled: (a.maxSessions ?? 0) > 0,
      maxSessions: (a.maxSessions ?? 0) > 0 ? a.maxSessions : null,
      sessionIdleTimeout:
          (a.maxSessions ?? 0) > 0 ? (a.sessionIdleTimeoutMinutes ?? 5) : null,
      rpmEnabled: (a.baseRpm ?? 0) > 0,
      baseRpm: (a.baseRpm ?? 0) > 0 ? a.baseRpm : null,
      rpmStrategy: a.rpmStrategy ?? 'tiered',
      rpmStickyBuffer: a.rpmStickyBuffer,
      userMsgQueueMode: a.userMsgQueueMode ?? '',
      tlsEnabled: a.enableTlsFingerprint == true,
      tlsProfileId: a.tlsFingerprintProfileId,
      sessionIdMasking: a.sessionIdMaskingEnabled == true,
      cacheTtlEnabled: a.cacheTtlOverrideEnabled == true,
      cacheTtlTarget: a.cacheTtlOverrideTarget ?? '5m',
      customBaseUrlEnabled: a.customBaseUrlEnabled == true,
      customBaseUrl: a.customBaseUrl ?? '',
    );
  }

  void applyToExtra(Map<String, dynamic> extra) {
    // 窗口费用
    if (windowCostEnabled && (windowCostLimit ?? 0) > 0) {
      extra['window_cost_limit'] = windowCostLimit;
      extra['window_cost_sticky_reserve'] = windowCostStickyReserve ?? 10;
    } else {
      extra
        ..remove('window_cost_limit')
        ..remove('window_cost_sticky_reserve');
    }
    // 会话限制
    if (sessionLimitEnabled && (maxSessions ?? 0) > 0) {
      extra['max_sessions'] = maxSessions;
      extra['session_idle_timeout_minutes'] = sessionIdleTimeout ?? 5;
    } else {
      extra
        ..remove('max_sessions')
        ..remove('session_idle_timeout_minutes');
    }
    // RPM
    if (rpmEnabled) {
      extra['base_rpm'] = (baseRpm ?? 0) > 0 ? baseRpm : defaultBaseRpm;
      extra['rpm_strategy'] = rpmStrategy;
      if ((rpmStickyBuffer ?? 0) > 0) {
        extra['rpm_sticky_buffer'] = rpmStickyBuffer;
      } else {
        extra.remove('rpm_sticky_buffer');
      }
    } else {
      extra
        ..remove('base_rpm')
        ..remove('rpm_strategy')
        ..remove('rpm_sticky_buffer');
    }
    // 用户消息限速(独立于 RPM)
    if (userMsgQueueMode.isNotEmpty) {
      extra['user_msg_queue_mode'] = userMsgQueueMode;
    } else {
      extra.remove('user_msg_queue_mode');
    }
    extra.remove('user_msg_queue_enabled'); // 清理旧字段
    // TLS 指纹
    if (tlsEnabled) {
      extra['enable_tls_fingerprint'] = true;
      if (tlsProfileId != null) {
        extra['tls_fingerprint_profile_id'] = tlsProfileId;
      } else {
        extra.remove('tls_fingerprint_profile_id');
      }
    } else {
      extra
        ..remove('enable_tls_fingerprint')
        ..remove('tls_fingerprint_profile_id');
    }
    // 会话 ID 掩码
    if (sessionIdMasking) {
      extra['session_id_masking_enabled'] = true;
    } else {
      extra.remove('session_id_masking_enabled');
    }
    // 缓存 TTL
    if (cacheTtlEnabled) {
      extra['cache_ttl_override_enabled'] = true;
      extra['cache_ttl_override_target'] = cacheTtlTarget;
    } else {
      extra
        ..remove('cache_ttl_override_enabled')
        ..remove('cache_ttl_override_target');
    }
    // 自定义 BaseURL
    if (customBaseUrlEnabled && customBaseUrl.trim().isNotEmpty) {
      extra['custom_base_url_enabled'] = true;
      extra['custom_base_url'] = customBaseUrl.trim();
    } else {
      extra
        ..remove('custom_base_url_enabled')
        ..remove('custom_base_url');
    }
  }
}
