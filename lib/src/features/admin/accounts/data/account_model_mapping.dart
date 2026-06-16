// 账号模型限制 / 预设映射 / 错误码 —— 对照 web
// `frontend/src/composables/useModelWhitelist.ts` 与 `constants/account.ts`。
//
// 模型限制统一存储于 `credentials.model_mapping`(Map<String,String>):
//   from == to  ⇒ 白名单(精确允许该模型)
//   from != to  ⇒ 映射重定向
// 通配符 `*` 仅允许出现在 from 末尾,且 to 不得含通配符。

/// 单条模型映射条目(from → to)。
class ModelMappingEntry {
  ModelMappingEntry({this.from = '', this.to = ''});
  String from;
  String to;
}

/// 预设映射(快捷追加按钮)。
class PresetMapping {
  const PresetMapping(this.label, this.from, this.to);
  final String label;
  final String from;
  final String to;
}

/// 常用错误码(自定义错误码 / 临时不可调度规则候选)。
class ErrorCodeOption {
  const ErrorCodeOption(this.value, this.label);
  final int value;
  final String label;
}

const List<ErrorCodeOption> kCommonErrorCodes = [
  ErrorCodeOption(401, 'Unauthorized'),
  ErrorCodeOption(403, 'Forbidden'),
  ErrorCodeOption(429, 'Rate Limit'),
  ErrorCodeOption(500, 'Server Error'),
  ErrorCodeOption(502, 'Bad Gateway'),
  ErrorCodeOption(503, 'Unavailable'),
  ErrorCodeOption(529, 'Overloaded'),
];

// ===== 各平台模型列表(白名单候选) =====

const List<String> _claudeModels = [
  'claude-3-5-sonnet-20241022',
  'claude-3-5-haiku-20241022',
  'claude-3-7-sonnet-20250219',
  'claude-sonnet-4-20250514',
  'claude-opus-4-20250514',
  'claude-opus-4-1-20250805',
  'claude-sonnet-4-5-20250929',
  'claude-haiku-4-5-20251001',
  'claude-opus-4-5-20251101',
  'claude-opus-4-6',
  'claude-opus-4-7',
  'claude-opus-4-8',
  'claude-sonnet-4-6',
  'claude-fable-5',
];

const List<String> _openaiModels = [
  'gpt-5.2', 'gpt-5.2-chat-latest', 'gpt-5.2-pro',
  'gpt-5.5', 'gpt-5.4', 'gpt-5.4-mini',
  'gpt-5.3-codex', 'gpt-5.3-codex-spark',
  'gpt-4o', 'gpt-4o-mini', 'gpt-4.1', 'o1', 'o3',
  'gpt-image-1', 'gpt-image-1.5', 'gpt-image-2',
];

const List<String> _geminiModels = [
  'gemini-2.0-flash',
  'gemini-2.5-flash',
  'gemini-2.5-flash-image',
  'gemini-2.5-pro',
  'gemini-3.5-flash',
  'gemini-3-flash-preview',
  'gemini-3-pro-preview',
  'gemini-3.1-flash-image',
];

const List<String> _antigravityModels = [
  'claude-fable-5',
  'claude-opus-4-6',
  'claude-opus-4-6-thinking',
  'claude-opus-4-7',
  'claude-opus-4-8',
  'claude-sonnet-4-6',
  'claude-sonnet-4-5',
  'gemini-2.5-flash',
  'gemini-2.5-pro',
  'gemini-3-flash',
  'gemini-3-pro-high',
  'gemini-3-pro-low',
  'gemini-3.1-pro-high',
  'gemini-3.1-pro-low',
];

/// 按平台返回白名单候选模型。
List<String> getModelsByPlatform(String platform) {
  switch (platform) {
    case 'openai':
      return _openaiModels;
    case 'gemini':
      return _geminiModels;
    case 'antigravity':
      return _antigravityModels;
    case 'anthropic':
    case 'claude':
    default:
      return _claudeModels;
  }
}

// ===== 各平台预设映射 =====

const List<PresetMapping> _anthropicPresets = [
  PresetMapping('Fable 5', 'claude-fable-5', 'claude-fable-5'),
  PresetMapping('Sonnet 4.5', 'claude-sonnet-4-5-20250929', 'claude-sonnet-4-5-20250929'),
  PresetMapping('Sonnet 4.6', 'claude-sonnet-4-6', 'claude-sonnet-4-6'),
  PresetMapping('Opus 4.5', 'claude-opus-4-5-20251101', 'claude-opus-4-5-20251101'),
  PresetMapping('Opus 4.6', 'claude-opus-4-6', 'claude-opus-4-6'),
  PresetMapping('Opus 4.8', 'claude-opus-4-8', 'claude-opus-4-8'),
  PresetMapping('Haiku 4.5', 'claude-haiku-4-5-20251001', 'claude-haiku-4-5-20251001'),
  PresetMapping('Opus->Sonnet', 'claude-opus-4-6', 'claude-sonnet-4-5-20250929'),
];

const List<PresetMapping> _openaiPresets = [
  PresetMapping('GPT-4o', 'gpt-4o', 'gpt-4o'),
  PresetMapping('GPT-4o Mini', 'gpt-4o-mini', 'gpt-4o-mini'),
  PresetMapping('GPT-4.1', 'gpt-4.1', 'gpt-4.1'),
  PresetMapping('o3', 'o3', 'o3'),
  PresetMapping('GPT-5.2', 'gpt-5.2', 'gpt-5.2'),
  PresetMapping('GPT-5.4', 'gpt-5.4', 'gpt-5.4'),
  PresetMapping('GPT-5.5', 'gpt-5.5', 'gpt-5.5'),
  PresetMapping('Opus->5.4', 'claude-opus-4-6', 'gpt-5.4'),
  PresetMapping('Sonnet->5.4', 'claude-sonnet-4-6', 'gpt-5.4'),
];

const List<PresetMapping> _geminiPresets = [
  PresetMapping('Flash 2.0', 'gemini-2.0-flash', 'gemini-2.0-flash'),
  PresetMapping('2.5 Flash', 'gemini-2.5-flash', 'gemini-2.5-flash'),
  PresetMapping('2.5 Image', 'gemini-2.5-flash-image', 'gemini-2.5-flash-image'),
  PresetMapping('2.5 Pro', 'gemini-2.5-pro', 'gemini-2.5-pro'),
  PresetMapping('3.5 Flash', 'gemini-3.5-flash', 'gemini-3.5-flash'),
  PresetMapping('3.1 Image', 'gemini-3.1-flash-image', 'gemini-3.1-flash-image'),
];

const List<PresetMapping> _antigravityPresets = [
  PresetMapping('Claude->Sonnet', 'claude-*', 'claude-sonnet-4-5'),
  PresetMapping('Fable 5', 'claude-fable-5', 'claude-fable-5'),
  PresetMapping('Sonnet->Sonnet', 'claude-sonnet-*', 'claude-sonnet-4-5'),
  PresetMapping('Opus->Opus', 'claude-opus-*', 'claude-opus-4-6-thinking'),
  PresetMapping('Haiku->Sonnet', 'claude-haiku-*', 'claude-sonnet-4-5'),
  PresetMapping('Gemini 3->Flash', 'gemini-3*', 'gemini-3-flash'),
  PresetMapping('Gemini 2.5->Flash', 'gemini-2.5*', 'gemini-2.5-flash'),
  PresetMapping('Sonnet 4.6', 'claude-sonnet-4-6', 'claude-sonnet-4-6'),
  PresetMapping('Opus 4.8', 'claude-opus-4-8', 'claude-opus-4-8'),
];

const List<PresetMapping> _bedrockPresets = [
  PresetMapping('Fable 5', 'claude-fable-5', 'anthropic.claude-fable-5'),
  PresetMapping('Opus 4.6', 'claude-opus-4-6', 'us.anthropic.claude-opus-4-6-v1'),
  PresetMapping('Opus 4.8', 'claude-opus-4-8', 'us.anthropic.claude-opus-4-8-v1'),
  PresetMapping('Sonnet 4.6', 'claude-sonnet-4-6', 'us.anthropic.claude-sonnet-4-6'),
  PresetMapping('Sonnet 4.5', 'claude-sonnet-4-5', 'us.anthropic.claude-sonnet-4-5-20250929-v1:0'),
  PresetMapping('Haiku 4.5', 'claude-haiku-4-5', 'us.anthropic.claude-haiku-4-5-20251001-v1:0'),
];

/// 按平台返回预设映射。
List<PresetMapping> getPresetMappingsByPlatform(String platform) {
  switch (platform) {
    case 'openai':
      return _openaiPresets;
    case 'gemini':
      return _geminiPresets;
    case 'antigravity':
      return _antigravityPresets;
    case 'bedrock':
      return _bedrockPresets;
    default:
      return _anthropicPresets;
  }
}

/// 校验通配符格式:`*` 只能在末尾,且至多一个。无通配符则有效。
bool isValidWildcardPattern(String pattern) {
  final i = pattern.indexOf('*');
  if (i == -1) return true;
  return i == pattern.length - 1 && pattern.lastIndexOf('*') == i;
}

/// 拆解 `model_mapping` 为白名单(from==to)与映射(from!=to)。
({List<String> allowedModels, List<ModelMappingEntry> modelMappings})
    splitModelMappingObject(Map<String, dynamic>? modelMapping) {
  final allowed = <String>[];
  final mappings = <ModelMappingEntry>[];
  if (modelMapping == null) return (allowedModels: allowed, modelMappings: mappings);
  modelMapping.forEach((rawFrom, rawTo) {
    if (rawTo is! String) return;
    final from = rawFrom.trim();
    final to = rawTo.trim();
    if (from.isEmpty || to.isEmpty) return;
    if (from == to) {
      allowed.add(from);
    } else {
      mappings.add(ModelMappingEntry(from: from, to: to));
    }
  });
  return (allowedModels: allowed, modelMappings: mappings);
}

/// 模型限制构建模式。
enum ModelRestrictionMode { whitelist, mapping, combined }

/// 由白名单 + 映射构建 `model_mapping`;无有效条目返回 null。
Map<String, String>? buildModelMappingObject(
  ModelRestrictionMode mode,
  List<String> allowedModels,
  List<ModelMappingEntry> modelMappings,
) {
  final mapping = <String, String>{};
  if (mode == ModelRestrictionMode.whitelist ||
      mode == ModelRestrictionMode.combined) {
    for (final m in allowedModels) {
      final model = m.trim();
      if (model.isEmpty) continue;
      // 白名单语义是「精确模型」,含通配符会破坏转发,跳过。
      if (model.contains('*')) continue;
      mapping[model] = model;
    }
  }
  if (mode == ModelRestrictionMode.mapping ||
      mode == ModelRestrictionMode.combined) {
    for (final m in modelMappings) {
      final from = m.from.trim();
      final to = m.to.trim();
      if (from.isEmpty || to.isEmpty) continue;
      if (!isValidWildcardPattern(from)) continue;
      if (to.contains('*')) continue;
      mapping[from] = to;
    }
  }
  return mapping.isEmpty ? null : mapping;
}

/// 解析池模式重试状态码输入:逗号/空白分隔,取 100–599 去重升序。
List<int> parsePoolModeRetryStatusCodes(String input) {
  if (input.trim().isEmpty) return const [];
  final seen = <int>{};
  for (final token in input.split(RegExp(r'[,\s]+'))) {
    final t = token.trim();
    if (t.isEmpty) continue;
    final n = int.tryParse(t);
    if (n == null || n < 100 || n > 599) continue;
    seen.add(n);
  }
  final out = seen.toList()..sort();
  return out;
}

/// 将状态码列表格式化回输入文本(去重升序,逗号分隔)。
String formatPoolModeRetryStatusCodes(dynamic value) {
  if (value is! List) return '';
  final seen = <int>{};
  for (final v in value) {
    final n = v is num ? v.toInt() : int.tryParse('$v');
    if (n == null || n < 100 || n > 599) continue;
    seen.add(n);
  }
  final out = seen.toList()..sort();
  return out.join(', ');
}
