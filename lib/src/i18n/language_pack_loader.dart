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

  /// 从用户选择的 .json 文件导入一个外置语言包。
  ///
  /// 先解析校验(非法 JSON / 缺 `@@locale` 会抛 [FormatException]),
  /// 再以 `<tag>.json` 写入外置目录(同语言覆盖)。返回导入的语言包。
  Future<LanguagePack> importPackFromFile(String sourcePath) async {
    final raw = await File(sourcePath).readAsString();
    final pack = LanguagePack.fromJsonString(raw); // 校验,失败抛异常
    final dir = await externalDir();
    await File('${dir.path}/${pack.tag}.json').writeAsString(raw);
    return pack;
  }

  /// 已导入的外置语言包(标签 → 文件路径)。
  Future<Map<String, String>> externalPackPaths() async {
    final result = <String, String>{};
    try {
      final dir = await externalDir();
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.toLowerCase().endsWith('.json')) {
          try {
            final pack =
                LanguagePack.fromJsonString(await entity.readAsString());
            result[pack.tag] = entity.path;
          } catch (_) {
            // 损坏文件忽略
          }
        }
      }
    } catch (_) {
      // 目录不可读视为无外置包
    }
    return result;
  }

  /// 删除指定标签的外置语言包文件。
  Future<void> deleteExternalByTag(String tag) async {
    final paths = await externalPackPaths();
    final path = paths[tag];
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }
}
