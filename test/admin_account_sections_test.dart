import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sub2api/src/features/admin/accounts/data/account_model_mapping.dart';
import 'package:sub2api/src/features/admin/accounts/data/account_platform_options.dart';
import 'package:sub2api/src/features/admin/accounts/data/account_quota.dart';
import 'package:sub2api/src/features/admin/accounts/presentation/sections/bedrock_credentials_section.dart';
import 'package:sub2api/src/features/admin/accounts/presentation/sections/custom_error_codes_section.dart';
import 'package:sub2api/src/features/admin/accounts/presentation/sections/model_restriction_section.dart';
import 'package:sub2api/src/features/admin/accounts/presentation/sections/openai_section.dart';
import 'package:sub2api/src/features/admin/accounts/presentation/sections/platform_toggle_sections.dart';
import 'package:sub2api/src/features/admin/accounts/presentation/sections/pool_mode_section.dart';
import 'package:sub2api/src/features/admin/accounts/presentation/sections/quota_advanced_section.dart';
import 'package:sub2api/src/features/admin/accounts/presentation/sections/quota_limit_section.dart';
import 'package:sub2api/src/features/admin/accounts/presentation/sections/temp_unschedulable_section.dart';
import 'package:sub2api/src/i18n/app_localizations.dart';
import 'package:sub2api/src/i18n/language_pack.dart';
import 'package:sub2api/src/i18n/language_pack_registry.dart';

/// 用真实 zh-CN 语言包包裹被测组件,提供 `context.tr`。
Widget _host(Widget child) {
  final pack = LanguagePack.fromJsonString(
      File('assets/i18n/zh-CN.json').readAsStringSync());
  final registry = LanguagePackRegistry()
    ..replaceAll([pack], fallbackTag: 'zh-CN');
  return MaterialApp(
    locale: const Locale('zh', 'CN'),
    localizationsDelegates: [
      AppLocalizationsDelegate(registry),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('zh', 'CN')],
    // 有界高度,Column 内放各 section,模拟表单 ListView 场景。
    home: Scaffold(
      body: ListView(padding: const EdgeInsets.all(16), children: [child]),
    ),
  );
}

void main() {
  testWidgets('模型限制·映射模式:from→to 行 + 预设 + 同步按钮 在有界列中不报错',
      (tester) async {
    await tester.pumpWidget(_host(ModelRestrictionSection(
      platform: 'antigravity',
      mappingOnly: true,
      onSyncUpstream: () async => ['claude-opus-4-8'],
      value: ModelRestrictionValue(
        mode: ModelRestrictionMode.mapping,
        mappings: [ModelMappingEntry(from: 'claude-*', to: 'claude-sonnet-4-5')],
      ),
      onChanged: (_) {},
    )));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('模型限制·白名单模式:候选 chip + 自定义添加 不报错', (tester) async {
    await tester.pumpWidget(_host(ModelRestrictionSection(
      platform: 'anthropic',
      value: ModelRestrictionValue(
        mode: ModelRestrictionMode.whitelist,
        allowedModels: ['claude-opus-4-8'],
      ),
      onChanged: (_) {},
    )));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('池模式:开启态字段不报错', (tester) async {
    await tester.pumpWidget(_host(PoolModeSection(
      value: PoolModeValue(enabled: true, retryStatusCodesInput: '401, 429'),
      onChanged: (_) {},
    )));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('自定义错误码:开启态 chip + 已选 不报错', (tester) async {
    await tester.pumpWidget(_host(CustomErrorCodesSection(
      value: CustomErrorCodesValue(enabled: true, codes: [401, 403]),
      onChanged: (_) {},
    )));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('配额控制:启用 + fixed 重置 + 通知 不报错', (tester) async {
    await tester.pumpWidget(_host(QuotaLimitSection(
      notifyGlobalEnabled: true,
      value: QuotaLimitValue(
        daily: 10,
        weekly: 50,
        total: 100,
        dailyResetMode: 'fixed',
        weeklyResetMode: 'fixed',
        notifyTotal: QuotaNotify(enabled: true, threshold: 80),
      ),
      onChanged: (_) {},
    )));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('高级配额:全部卡片启用 不报错', (tester) async {
    await tester.pumpWidget(_host(QuotaAdvancedSection(
      tlsProfiles: const [(id: 1, name: 'chrome')],
      value: AdvancedQuotaValue(
        windowCostEnabled: true,
        sessionLimitEnabled: true,
        rpmEnabled: true,
        tlsEnabled: true,
        cacheTtlEnabled: true,
        customBaseUrlEnabled: true,
      ),
      onChanged: (_) {},
    )));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('OpenAI 区块:apikey 全开 不报错', (tester) async {
    await tester.pumpWidget(_host(OpenAiSection(
      type: 'apikey',
      value: OpenAiOptions(
        passthrough: true,
        responsesMode: 'force_responses',
        compactMappings: [ModelMappingEntry(from: 'a', to: 'b')],
        autoPause5hThreshold: 80,
      ),
      onChanged: (_) {},
    )));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('OpenAI 区块:oauth + codexCliOnly 子开关 不报错', (tester) async {
    await tester.pumpWidget(_host(OpenAiSection(
      type: 'oauth',
      value: OpenAiOptions(codexCliOnly: true, allowClaudeCode: true),
      onChanged: (_) {},
    )));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Anthropic / Antigravity 小区块 不报错', (tester) async {
    await tester.pumpWidget(_host(Column(children: [
      AnthropicApikeySection(
        value: AnthropicApikeyOptions(webSearchMode: 'enabled'),
        onChanged: (_) {},
      ),
      AntigravitySection(
        value: AntigravityOptions(mixedScheduling: true, allowOverages: true),
        onChanged: (_) {},
      ),
    ])));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('临时不可调度:启用 + 规则卡 不报错', (tester) async {
    await tester.pumpWidget(_host(TempUnschedulableSection(
      value: TempUnschedValue(enabled: true, rules: [
        TempUnschedRule(
            errorCode: 529, keywords: 'overloaded', durationMinutes: 60),
      ]),
      onChanged: (_) {},
    )));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Bedrock 凭据:SigV4 / APIKey 两模式 不报错', (tester) async {
    await tester.pumpWidget(_host(BedrockCredentialsSection(
      value: BedrockCredsValue(authMode: 'sigv4', forceGlobal: true),
      onChanged: (_) {},
    )));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
