import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import 'language_pack.dart';

/// 负责发现并加载语言包,支持两个来源:
///
/// 1. **内置包** —— 打包进应用的 `assets/i18n/*.json`,由 `manifest.json` 列出。
/// 2. **外置包** —— 应用文档目录下 `sub2api/i18n/*.json`,用户可直接投放,
///    无需重新编译/安装即可新增语言(满足「语言包热插拔」需求)。
class LanguagePackLoader {
  static const String _assetDir = 'assets/i18n';
  static const String _manifestAsset = '$_assetDir/manifest.json';

  String _fallbackTag = 'en-US';

  /// manifest 中声明的回退语言标签。
  String get fallbackTag => _fallbackTag;

  /// 加载内置语言包(读取 manifest 后逐个解析)。
  Future<List<LanguagePack>> loadBuiltIn() async {
    final manifestRaw = await rootBundle.loadString(_manifestAsset);
    final manifest = json.decode(manifestRaw) as Map<String, dynamic>;
    _fallbackTag = (manifest['fallback'] as String?)?.trim() ?? _fallbackTag;
    final files = (manifest['packs'] as List? ?? const [])
        .map((e) => e.toString())
        .toList();

    final packs = <LanguagePack>[];
    for (final file in files) {
      try {
        final raw = await rootBundle.loadString('$_assetDir/$file');
        packs.add(LanguagePack.fromJsonString(raw));
      } catch (e) {
        debugPrint('跳过损坏的内置语言包 $file: $e');
      }
    }
    return packs;
  }

  /// 外置语言包目录,不存在时自动创建。
  Future<Directory> externalDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/sub2api/i18n');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 加载外置语言包,逐个容错(损坏的包跳过而非整体失败)。
  Future<List<LanguagePack>> loadExternal() async {
    final List<LanguagePack> packs = [];
    try {
      final dir = await externalDir();
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.toLowerCase().endsWith('.json')) {
          try {
            packs.add(LanguagePack.fromJsonString(await entity.readAsString()));
          } catch (e) {
            debugPrint('跳过损坏的外置语言包 ${entity.path}: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('读取外置语言包目录失败: $e');
    }
    return packs;
  }

  /// 内置 + 外置合并加载;外置包排在后面,可覆盖同标签内置包。
  Future<List<LanguagePack>> loadAll() async {
    final builtIn = await loadBuiltIn();
    final external = await loadExternal();
    return [...builtIn, ...external];
  }
}
