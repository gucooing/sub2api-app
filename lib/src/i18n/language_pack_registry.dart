import 'package:flutter/widgets.dart';

import 'language_pack.dart';

/// 已加载语言包的内存注册表。
///
/// 由启动流程(`main`)填充内置 + 外置语言包,被本地化委托 [AppLocalizationsDelegate]
/// 在切换语言时同步查询。运行时导入新语言包后调用 [replaceAll] 即可热更新。
class LanguagePackRegistry {
  final Map<String, LanguagePack> _byTag = <String, LanguagePack>{};
  LanguagePack? _fallback;

  /// 回退语言包(当所选语言缺少某个键时使用)。
  LanguagePack? get fallback => _fallback;

  /// 当前已加载的全部语言包(用于语言选择列表)。
  List<LanguagePack> get all => _byTag.values.toList(growable: false);

  /// 全部已支持的 [Locale],供 `MaterialApp.supportedLocales` 使用。
  List<Locale> get supportedLocales =>
      all.map((p) => p.locale).toList(growable: false);

  bool get isEmpty => _byTag.isEmpty;

  /// 用一批语言包整体替换注册表内容,并确定回退包。
  ///
  /// 相同 [LanguagePack.tag] 的后者覆盖前者(便于外置包覆盖内置包)。
  void replaceAll(List<LanguagePack> packs, {required String fallbackTag}) {
    _byTag
      ..clear()
      ..addEntries(packs.map((p) => MapEntry(p.tag, p)));
    _fallback = _byTag[fallbackTag] ?? (packs.isNotEmpty ? packs.first : null);
  }

  /// 按「精确标签 → 同语言 → 回退包」的顺序解析出最合适的语言包。
  LanguagePack? resolve(Locale locale) {
    final exact = _byTag.values.firstWhereOrNull(
      (p) => p.locale.languageCode == locale.languageCode &&
          p.locale.countryCode == locale.countryCode,
    );
    if (exact != null) return exact;

    final sameLanguage = _byTag.values.firstWhereOrNull(
      (p) => p.locale.languageCode == locale.languageCode,
    );
    if (sameLanguage != null) return sameLanguage;

    return _fallback;
  }
}

extension _FirstWhereOrNull<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
