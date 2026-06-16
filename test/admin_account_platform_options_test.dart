import 'package:flutter_test/flutter_test.dart';
import 'package:sub2api/src/features/admin/accounts/data/account_model_mapping.dart';
import 'package:sub2api/src/features/admin/accounts/data/account_platform_options.dart';

void main() {
  group('OpenAiOptions.applyToExtra', () {
    test('apikey: WS 键 + responses + 透传 + 自动暂停换算', () {
      final v = OpenAiOptions(
        passthrough: true,
        wsMode: 'ctx_pool',
        responsesMode: 'force_responses',
        autoPause5hThreshold: 80,
      );
      final e = <String, dynamic>{};
      v.applyToExtra(e, 'apikey', hadCodexCliOnly: false);
      expect(e['openai_apikey_responses_websockets_v2_mode'], 'ctx_pool');
      expect(e['openai_apikey_responses_websockets_v2_enabled'], true);
      expect(e['openai_passthrough'], true);
      expect(e['openai_responses_mode'], 'force_responses');
      expect(e['auto_pause_5h_threshold'], closeTo(0.8, 1e-9));
    });

    test('oauth: codex_cli_only 关闭但曾开启 → 显式 false', () {
      final e = <String, dynamic>{};
      OpenAiOptions(codexCliOnly: false)
          .applyToExtra(e, 'oauth', hadCodexCliOnly: true);
      expect(e['codex_cli_only'], false);
    });

    test('图像桥接 inherit 删除键,enabled 写 bool', () {
      final e = <String, dynamic>{'codex_image_generation_bridge': true};
      OpenAiOptions(imageBridge: 'inherit')
          .applyToExtra(e, 'oauth', hadCodexCliOnly: false);
      expect(e.containsKey('codex_image_generation_bridge'), isFalse);
      final e2 = <String, dynamic>{};
      OpenAiOptions(imageBridge: 'disabled')
          .applyToExtra(e2, 'oauth', hadCodexCliOnly: false);
      expect(e2['codex_image_generation_bridge'], false);
    });

    test('端点能力:两项全选删除键,单项写数组', () {
      final c1 = <String, dynamic>{};
      OpenAiOptions(capabilities: {'chat_completions', 'embeddings'})
          .applyToCredentials(c1, 'apikey');
      expect(c1.containsKey('openai_capabilities'), isFalse);
      final c2 = <String, dynamic>{};
      OpenAiOptions(capabilities: {'embeddings'})
          .applyToCredentials(c2, 'apikey');
      expect(c2['openai_capabilities'], ['embeddings']);
    });

    test('compact 映射写 credentials', () {
      final c = <String, dynamic>{};
      OpenAiOptions(compactMappings: [ModelMappingEntry(from: 'a', to: 'b')])
          .applyToCredentials(c, 'oauth');
      expect(c['compact_model_mapping'], {'a': 'b'});
    });
  });

  group('AnthropicApikeyOptions', () {
    test('透传 + 联网搜索三态', () {
      final e = <String, dynamic>{};
      AnthropicApikeyOptions(passthrough: true, webSearchMode: 'enabled')
          .applyToExtra(e, webSearchGlobal: true);
      expect(e['anthropic_passthrough'], true);
      expect(e['web_search_emulation'], 'enabled');

      final e2 = <String, dynamic>{'web_search_emulation': 'enabled'};
      AnthropicApikeyOptions(webSearchMode: 'default')
          .applyToExtra(e2, webSearchGlobal: true);
      expect(e2.containsKey('web_search_emulation'), isFalse);
    });
  });

  group('AntigravityOptions', () {
    test('mixed/overages 写删', () {
      final e = <String, dynamic>{};
      AntigravityOptions(mixedScheduling: true, allowOverages: true)
          .applyToExtra(e);
      expect(e['mixed_scheduling'], true);
      expect(e['allow_overages'], true);
      final e2 = <String, dynamic>{'allow_overages': true};
      AntigravityOptions().applyToExtra(e2);
      expect(e2.containsKey('allow_overages'), isFalse);
    });
  });

  group('TempUnschedValue', () {
    test('有效规则写入;关键词拆分为数组', () {
      final creds = <String, dynamic>{};
      final ok = TempUnschedValue(enabled: true, rules: [
        TempUnschedRule(
            errorCode: 529, keywords: 'overloaded, too many', durationMinutes: 60),
      ]).applyToCredentials(creds);
      expect(ok, isTrue);
      expect(creds['temp_unschedulable_enabled'], true);
      final rules = creds['temp_unschedulable_rules'] as List;
      expect(rules.first['keywords'], ['overloaded', 'too many']);
    });

    test('开启但规则无效 → false', () {
      final creds = <String, dynamic>{};
      final ok = TempUnschedValue(enabled: true, rules: [
        TempUnschedRule(errorCode: 99, keywords: '', durationMinutes: 0),
      ]).applyToCredentials(creds);
      expect(ok, isFalse);
    });

    test('关闭 → 删除键', () {
      final creds = <String, dynamic>{
        'temp_unschedulable_enabled': true,
        'temp_unschedulable_rules': [],
      };
      TempUnschedValue(enabled: false).applyToCredentials(creds);
      expect(creds.containsKey('temp_unschedulable_enabled'), isFalse);
    });
  });
}
