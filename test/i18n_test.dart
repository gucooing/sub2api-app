import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sub2api/src/i18n/app_localizations.dart';
import 'package:sub2api/src/i18n/language_pack.dart';
import 'package:sub2api/src/i18n/language_pack_registry.dart';

void main() {
  group('LanguagePack', () {
    test('flattens nested keys and strips @@ meta', () {
      final pack = LanguagePack.fromJsonString('''
        {
          "@@locale": "en-US",
          "@@name": "English",
          "@@nativeName": "English",
          "settings": { "title": "Settings", "language": "Language" }
        }
      ''');

      expect(pack.tag, 'en-US');
      expect(pack.nativeName, 'English');
      expect(pack.locale, const Locale('en', 'US'));
      expect(pack.lookup('settings.title'), 'Settings');
      expect(pack.lookup('settings.language'), 'Language');
      // 元信息不计入翻译表
      expect(pack.lookup('@@name'), isNull);
    });

    test('parseLocale handles language-only and region tags', () {
      expect(LanguagePack.parseLocale('zh'), const Locale('zh'));
      expect(LanguagePack.parseLocale('zh-CN'), const Locale('zh', 'CN'));
    });
  });

  group('LanguagePackRegistry', () {
    final en = LanguagePack.fromJsonString(
        '{"@@locale":"en-US","@@nativeName":"English","greet":"Hi"}');
    final zh = LanguagePack.fromJsonString(
        '{"@@locale":"zh-CN","@@nativeName":"简体中文","greet":"你好"}');

    test('resolves exact, then language-only, then fallback', () {
      final registry = LanguagePackRegistry()
        ..replaceAll([en, zh], fallbackTag: 'en-US');

      expect(registry.resolve(const Locale('zh', 'CN'))?.tag, 'zh-CN');
      // 同语言不同地区 → 命中同语言包
      expect(registry.resolve(const Locale('zh', 'TW'))?.tag, 'zh-CN');
      // 完全不支持的语言 → 回退
      expect(registry.resolve(const Locale('fr'))?.tag, 'en-US');
    });
  });

  group('内置语言包', () {
    test('zh-CN 与 en-US 键集一致', () {
      final zh = LanguagePack.fromJsonString(
          File('assets/i18n/zh-CN.json').readAsStringSync());
      final en = LanguagePack.fromJsonString(
          File('assets/i18n/en-US.json').readAsStringSync());

      final zhKeys = zh.messages.keys.toSet();
      final enKeys = en.messages.keys.toSet();
      expect(zhKeys.difference(enKeys), isEmpty,
          reason: 'zh-CN 比 en-US 多出的键');
      expect(enKeys.difference(zhKeys), isEmpty,
          reason: 'en-US 比 zh-CN 多出的键');
    });
  });

  group('AppLocalizations', () {
    final en = LanguagePack.fromJsonString(
        '{"@@locale":"en-US","@@nativeName":"English","greet":"Hi"}');
    final zh = LanguagePack.fromJsonString(
        '{"@@locale":"zh-CN","@@nativeName":"简体中文","greet":"你好"}');

    test('falls back to fallback pack, then to the key itself', () {
      final l10n = AppLocalizations(zh, en);
      expect(l10n.tr('greet'), '你好');
      // 两包都缺失的键回退为键名,避免空白
      expect(l10n.tr('missing.key'), 'missing.key');
    });

    test('interpolates {placeholders}', () {
      final pack = LanguagePack.fromJsonString(
          '{"@@locale":"en-US","welcome":"Hi {name}"}');
      final l10n = AppLocalizations(pack, pack);
      expect(l10n.tr('welcome', params: {'name': 'Sam'}), 'Hi Sam');
    });
  });
}
