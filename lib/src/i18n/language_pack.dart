import 'dart:convert';

import 'package:flutter/widgets.dart';

/// 一个语言包:对应某个 locale 的全部界面文本。
///
/// 文本以「扁平化点路径键」存储(如 `settings.title`),由嵌套 JSON 递归展开而来,
/// 便于按键查找与逐级回退。元信息键以 `@@` 前缀标记,不计入翻译文本。
@immutable
class LanguagePack {
  const LanguagePack({
    required this.locale,
    required this.tag,
    required this.name,
    required this.nativeName,
    required this.messages,
  });

  /// 解析后的 Flutter [Locale],用于与系统语言匹配。
  final Locale locale;

  /// 原始语言标签,如 `zh-CN`、`en-US`。
  final String tag;

  /// 语言的通用名(英文),如 `Simplified Chinese`。
  final String name;

  /// 语言的自称,如 `简体中文`,用于语言选择列表展示。
  final String nativeName;

  /// 扁平化后的翻译表:点路径键 → 文本。
  final Map<String, String> messages;

  /// 从 JSON 字符串构建语言包。
  ///
  /// 约定的元信息键:`@@locale`(必填)、`@@name`、`@@nativeName`。
  factory LanguagePack.fromJsonString(String source) {
    final decoded = json.decode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('语言包根节点必须是 JSON 对象');
    }
    final tag = (decoded['@@locale'] as String?)?.trim();
    if (tag == null || tag.isEmpty) {
      throw const FormatException('语言包缺少 @@locale 字段');
    }
    final messages = <String, String>{};
    _flatten('', decoded, messages);
    return LanguagePack(
      locale: parseLocale(tag),
      tag: tag,
      name: (decoded['@@name'] as String?)?.trim() ?? tag,
      nativeName: (decoded['@@nativeName'] as String?)?.trim() ??
          (decoded['@@name'] as String?)?.trim() ??
          tag,
      messages: messages,
    );
  }

  /// 查找某个键的文本,未命中返回 null(由上层决定回退策略)。
  String? lookup(String key) => messages[key];

  /// 将 `zh-CN` / `en_US` / `zh` 等标签解析为 [Locale]。
  static Locale parseLocale(String tag) {
    final parts = tag.replaceAll('_', '-').split('-');
    if (parts.length == 1) return Locale(parts[0]);
    if (parts.length == 2) return Locale(parts[0], parts[1]);
    return Locale.fromSubtags(
      languageCode: parts[0],
      scriptCode: parts[1],
      countryCode: parts[2],
    );
  }

  static void _flatten(
    String prefix,
    Map<String, dynamic> node,
    Map<String, String> out,
  ) {
    node.forEach((key, value) {
      if (key.startsWith('@@')) return; // 元信息不计入翻译
      final fullKey = prefix.isEmpty ? key : '$prefix.$key';
      if (value is Map<String, dynamic>) {
        _flatten(fullKey, value, out);
      } else if (value != null) {
        out[fullKey] = value.toString();
      }
    });
  }
}
