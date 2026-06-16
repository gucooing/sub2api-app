import 'package:flutter_test/flutter_test.dart';
import 'package:sub2api/src/features/admin/accounts/data/account_model_mapping.dart';

void main() {
  group('splitModelMappingObject', () {
    test('区分白名单(from==to)与映射(from!=to)', () {
      final r = splitModelMappingObject({
        'claude-opus-4-8': 'claude-opus-4-8', // 白名单
        'claude-opus-4-6': 'claude-sonnet-4-6', // 映射
        'bad': 123, // 非字符串值忽略
        '': 'x', // 空键忽略
      });
      expect(r.allowedModels, ['claude-opus-4-8']);
      expect(r.modelMappings.length, 1);
      expect(r.modelMappings.first.from, 'claude-opus-4-6');
      expect(r.modelMappings.first.to, 'claude-sonnet-4-6');
    });

    test('null 返回空', () {
      final r = splitModelMappingObject(null);
      expect(r.allowedModels, isEmpty);
      expect(r.modelMappings, isEmpty);
    });
  });

  group('buildModelMappingObject', () {
    test('whitelist 模式跳过通配符项', () {
      final m = buildModelMappingObject(
        ModelRestrictionMode.whitelist,
        ['claude-opus-4-8', 'claude-*', ' '],
        [],
      );
      expect(m, {'claude-opus-4-8': 'claude-opus-4-8'});
    });

    test('mapping 模式校验通配符: from 末尾合法, to 禁通配符', () {
      final m = buildModelMappingObject(
        ModelRestrictionMode.mapping,
        [],
        [
          ModelMappingEntry(from: 'claude-*', to: 'claude-sonnet-4-5'), // ok
          ModelMappingEntry(from: 'cl*ude', to: 'x'), // from 通配符非末尾 → 跳过
          ModelMappingEntry(from: 'a', to: 'b*'), // to 含通配符 → 跳过
          ModelMappingEntry(from: '', to: 'b'), // 空 → 跳过
        ],
      );
      expect(m, {'claude-*': 'claude-sonnet-4-5'});
    });

    test('combined 合并白名单与映射;全空返回 null', () {
      expect(
        buildModelMappingObject(ModelRestrictionMode.combined, [], []),
        isNull,
      );
      final m = buildModelMappingObject(
        ModelRestrictionMode.combined,
        ['gpt-4o'],
        [ModelMappingEntry(from: 'a', to: 'b')],
      );
      expect(m, {'gpt-4o': 'gpt-4o', 'a': 'b'});
    });
  });

  group('isValidWildcardPattern', () {
    test('合法/非法', () {
      expect(isValidWildcardPattern('claude-*'), isTrue);
      expect(isValidWildcardPattern('claude'), isTrue);
      expect(isValidWildcardPattern('cl*ude'), isFalse);
      expect(isValidWildcardPattern('a**'), isFalse);
    });
  });

  group('pool mode 重试状态码', () {
    test('解析: 去重/升序/越界剔除', () {
      expect(parsePoolModeRetryStatusCodes('429, 403 401 401 99 600'),
          [401, 403, 429]);
      expect(parsePoolModeRetryStatusCodes('  '), isEmpty);
    });

    test('格式化往返', () {
      expect(formatPoolModeRetryStatusCodes([429, 401, 403, 401]),
          '401, 403, 429');
      expect(formatPoolModeRetryStatusCodes('not a list'), '');
    });
  });

  group('预设/模型按平台', () {
    test('平台映射不串台', () {
      expect(getPresetMappingsByPlatform('bedrock').first.to,
          startsWith('anthropic.'));
      expect(getModelsByPlatform('openai'), contains('gpt-4o'));
      expect(getModelsByPlatform('anthropic'), contains('claude-opus-4-8'));
      expect(getModelsByPlatform('antigravity'), contains('gemini-3-flash'));
    });
  });
}
