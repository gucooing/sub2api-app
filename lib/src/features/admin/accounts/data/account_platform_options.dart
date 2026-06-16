import 'account_model_mapping.dart';
import 'admin_accounts_api.dart';

/// 临时不可调度规则(命中错误码 + 关键词 → 暂停一段时间)。
class TempUnschedRule {
  TempUnschedRule({
    this.errorCode,
    this.keywords = '',
    this.durationMinutes = 30,
    this.description = '',
  });
  int? errorCode;
  String keywords; // 逗号/分号分隔
  int? durationMinutes;
  String description;
}

/// 临时不可调度配置(写入 credentials,适用所有类型)。
class TempUnschedValue {
  TempUnschedValue({this.enabled = false, List<TempUnschedRule>? rules})
      : rules = rules ?? [];
  bool enabled;
  List<TempUnschedRule> rules;

  static List<String> _splitKeywords(String s) => s
      .split(RegExp(r'[,;]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  static String _joinKeywords(dynamic v) {
    if (v is List) {
      return v.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).join(', ');
    }
    return v is String ? v : '';
  }

  factory TempUnschedValue.fromCredentials(Map<String, dynamic> creds) {
    final raw = creds['temp_unschedulable_rules'];
    final rules = <TempUnschedRule>[];
    if (raw is List) {
      for (final r in raw) {
        if (r is Map) {
          rules.add(TempUnschedRule(
            errorCode: (r['error_code'] as num?)?.toInt(),
            keywords: _joinKeywords(r['keywords']),
            durationMinutes: (r['duration_minutes'] as num?)?.toInt(),
            description: r['description'] as String? ?? '',
          ));
        }
      }
    }
    return TempUnschedValue(
      enabled: creds['temp_unschedulable_enabled'] == true,
      rules: rules,
    );
  }

  /// 写入 credentials;返回 false 表示开启但无有效规则(应阻止保存)。
  bool applyToCredentials(Map<String, dynamic> creds) {
    if (!enabled) {
      creds
        ..remove('temp_unschedulable_enabled')
        ..remove('temp_unschedulable_rules');
      return true;
    }
    final out = <Map<String, dynamic>>[];
    for (final r in rules) {
      final code = r.errorCode ?? 0;
      final dur = r.durationMinutes ?? 0;
      final kws = _splitKeywords(r.keywords);
      if (code < 100 || code > 599) continue;
      if (dur <= 0) continue;
      if (kws.isEmpty) continue;
      out.add({
        'error_code': code,
        'keywords': kws,
        'duration_minutes': dur,
        'description': r.description.trim(),
      });
    }
    if (out.isEmpty) return false;
    creds['temp_unschedulable_enabled'] = true;
    creds['temp_unschedulable_rules'] = out;
    return true;
  }
}

/// OpenAI(oauth / apikey)平台开关集合。
class OpenAiOptions {
  OpenAiOptions({
    this.passthrough = false,
    this.wsMode = 'off', // off / ctx_pool / passthrough
    this.responsesMode = 'auto', // auto / force_responses / force_chat_completions
    Set<String>? capabilities,
    this.codexCliOnly = false,
    this.allowClaudeCode = false,
    this.compactMode = 'auto', // auto / force_on / force_off
    List<ModelMappingEntry>? compactMappings,
    this.imageBridge = 'inherit', // inherit / enabled / disabled
    this.autoPause5hThreshold, // 百分比(0-100)
    this.autoPause5hDisabled = false,
    this.autoPause7dThreshold,
    this.autoPause7dDisabled = false,
  })  : capabilities = capabilities ?? {'chat_completions', 'embeddings'},
        compactMappings = compactMappings ?? [];

  bool passthrough;
  String wsMode;
  String responsesMode;
  Set<String> capabilities; // chat_completions / embeddings
  bool codexCliOnly;
  bool allowClaudeCode;
  String compactMode;
  List<ModelMappingEntry> compactMappings;
  String imageBridge;
  num? autoPause5hThreshold;
  bool autoPause5hDisabled;
  num? autoPause7dThreshold;
  bool autoPause7dDisabled;

  bool get textGenEnabled => capabilities.contains('chat_completions');

  factory OpenAiOptions.fromAccount(AdminAccount a) {
    final e = a.extra;
    final isApiKey = a.type == 'apikey';
    // WS 模式:apikey / oauth 分键。
    String wsKey(String role) =>
        e['openai_${role}_responses_websockets_v2_mode'] as String? ?? 'off';
    final caps = <String>{};
    final rawCaps = a.credentials['openai_capabilities'];
    if (rawCaps is List) {
      for (final c in rawCaps) {
        if (c == 'chat_completions' || c == 'embeddings') caps.add('$c');
      }
    }
    if (caps.isEmpty) caps.addAll({'chat_completions', 'embeddings'});

    final compact = <ModelMappingEntry>[];
    final rawCompact = a.credentials['compact_model_mapping'];
    if (rawCompact is Map) {
      rawCompact.forEach((k, v) =>
          compact.add(ModelMappingEntry(from: '$k', to: '$v')));
    }

    dynamic bridge = e['codex_image_generation_bridge'];
    bridge ??= e['codex_image_generation_bridge_enabled'];
    final bridgeMode = bridge == true
        ? 'enabled'
        : bridge == false
            ? 'disabled'
            : 'inherit';

    final allowList = e['codex_cli_only_allowed_clients'];
    return OpenAiOptions(
      passthrough:
          e['openai_passthrough'] == true || e['openai_oauth_passthrough'] == true,
      wsMode: isApiKey ? wsKey('apikey') : wsKey('oauth'),
      responsesMode: isApiKey
          ? _normResponses(e['openai_responses_mode'])
          : 'auto',
      capabilities: caps,
      codexCliOnly: e['codex_cli_only'] == true,
      allowClaudeCode: allowList is List && allowList.contains('claude_code'),
      compactMode: e['openai_compact_mode'] as String? ?? 'auto',
      compactMappings: compact,
      imageBridge: bridgeMode,
      autoPause5hThreshold: e['auto_pause_5h_threshold'] is num
          ? (e['auto_pause_5h_threshold'] as num) * 100
          : null,
      autoPause5hDisabled: e['auto_pause_5h_disabled'] == true,
      autoPause7dThreshold: e['auto_pause_7d_threshold'] is num
          ? (e['auto_pause_7d_threshold'] as num) * 100
          : null,
      autoPause7dDisabled: e['auto_pause_7d_disabled'] == true,
    );
  }

  static String _normResponses(dynamic v) =>
      (v == 'force_responses' || v == 'force_chat_completions') ? '$v' : 'auto';

  /// 写入 extra。[type] 决定 WS 键;[hadCodexCliOnly] 用于关闭时显式写 false。
  void applyToExtra(Map<String, dynamic> extra, String type,
      {required bool hadCodexCliOnly}) {
    final isApiKey = type == 'apikey';
    final role = isApiKey ? 'apikey' : 'oauth';
    extra['openai_${role}_responses_websockets_v2_mode'] = wsMode;
    extra['openai_${role}_responses_websockets_v2_enabled'] = wsMode != 'off';
    extra
      ..remove('responses_websockets_v2_enabled')
      ..remove('openai_ws_enabled');

    if (passthrough) {
      extra['openai_passthrough'] = true;
    } else {
      extra
        ..remove('openai_passthrough')
        ..remove('openai_oauth_passthrough');
    }

    if (compactMode == 'auto') {
      extra.remove('openai_compact_mode');
    } else {
      extra['openai_compact_mode'] = compactMode;
    }

    if (isApiKey) {
      if (!textGenEnabled || responsesMode == 'auto') {
        extra.remove('openai_responses_mode');
      } else {
        extra['openai_responses_mode'] = responsesMode;
      }
    }

    void pause(String key, num? pct, bool disabled, String disabledKey) {
      if (pct != null && pct > 0) {
        extra[key] = pct / 100;
      } else {
        extra.remove(key);
      }
      if (disabled) {
        extra[disabledKey] = true;
      } else {
        extra.remove(disabledKey);
      }
    }

    pause('auto_pause_5h_threshold', autoPause5hThreshold, autoPause5hDisabled,
        'auto_pause_5h_disabled');
    pause('auto_pause_7d_threshold', autoPause7dThreshold, autoPause7dDisabled,
        'auto_pause_7d_disabled');

    extra.remove('codex_image_generation_bridge_enabled');
    if (imageBridge == 'inherit') {
      extra.remove('codex_image_generation_bridge');
    } else {
      extra['codex_image_generation_bridge'] = imageBridge == 'enabled';
    }

    if (!isApiKey) {
      if (codexCliOnly) {
        extra['codex_cli_only'] = true;
      } else if (hadCodexCliOnly) {
        extra['codex_cli_only'] = false;
      } else {
        extra.remove('codex_cli_only');
      }
      if (codexCliOnly && allowClaudeCode) {
        extra['codex_cli_only_allowed_clients'] = ['claude_code'];
      } else {
        extra.remove('codex_cli_only_allowed_clients');
      }
    }
  }

  /// 写入 credentials(端点能力 + compact 映射)。
  void applyToCredentials(Map<String, dynamic> creds, String type) {
    if (type == 'apikey') {
      final caps = ['chat_completions', 'embeddings']
          .where(capabilities.contains)
          .toList();
      if (caps.length == 2 || caps.isEmpty) {
        creds.remove('openai_capabilities');
      } else {
        creds['openai_capabilities'] = caps;
      }
    }
    final cm = buildModelMappingObject(
        ModelRestrictionMode.mapping, const [], compactMappings);
    if (cm != null) {
      creds['compact_model_mapping'] = cm;
    } else {
      creds.remove('compact_model_mapping');
    }
  }
}

/// Anthropic API Key 平台开关。
class AnthropicApikeyOptions {
  AnthropicApikeyOptions({
    this.passthrough = false,
    this.webSearchMode = 'default', // default / enabled / disabled
  });
  bool passthrough;
  String webSearchMode;

  factory AnthropicApikeyOptions.fromAccount(AdminAccount a) {
    final ws = a.extra['web_search_emulation'];
    final mode = (ws == 'enabled' || ws == 'disabled')
        ? '$ws'
        : (ws == true ? 'enabled' : 'default');
    return AnthropicApikeyOptions(
      passthrough: a.extra['anthropic_passthrough'] == true,
      webSearchMode: mode,
    );
  }

  void applyToExtra(Map<String, dynamic> extra, {required bool webSearchGlobal}) {
    if (passthrough) {
      extra['anthropic_passthrough'] = true;
    } else {
      extra.remove('anthropic_passthrough');
    }
    if (webSearchGlobal) {
      if (webSearchMode == 'default') {
        extra.remove('web_search_emulation');
      } else {
        extra['web_search_emulation'] = webSearchMode;
      }
    }
  }
}

/// Antigravity 平台开关。
class AntigravityOptions {
  AntigravityOptions({this.mixedScheduling = false, this.allowOverages = false});
  bool mixedScheduling; // 只读展示
  bool allowOverages;

  factory AntigravityOptions.fromAccount(AdminAccount a) => AntigravityOptions(
        mixedScheduling: a.extra['mixed_scheduling'] == true,
        allowOverages: a.extra['allow_overages'] == true,
      );

  void applyToExtra(Map<String, dynamic> extra) {
    if (mixedScheduling) {
      extra['mixed_scheduling'] = true;
    } else {
      extra.remove('mixed_scheduling');
    }
    if (allowOverages) {
      extra['allow_overages'] = true;
    } else {
      extra.remove('allow_overages');
    }
  }
}
