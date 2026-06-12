import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'language_pack.dart';
import 'language_pack_registry.dart';

/// 暴露给界面的本地化访问入口。通过 `AppLocalizations.of(context)` 获取,
/// 或使用 `context.tr('key')` 扩展。
///
/// 查找顺序:当前语言包 → 回退语言包 → 键本身(避免界面出现空白)。
class AppLocalizations {
  const AppLocalizations(this.pack, this.fallback);

  final LanguagePack pack;
  final LanguagePack? fallback;

  static AppLocalizations of(BuildContext context) {
    final instance =
        Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(instance != null, '未找到 AppLocalizations,请确认已注册其 delegate');
    return instance!;
  }

  /// 翻译指定键;`params` 用于替换文本中的 `{name}` 占位符。
  String tr(String key, {Map<String, String>? params}) {
    var template = pack.lookup(key) ?? fallback?.lookup(key) ?? key;
    if (params != null && params.isNotEmpty) {
      params.forEach((name, value) {
        template = template.replaceAll('{$name}', value);
      });
    }
    return template;
  }
}

/// 自定义本地化委托。由于语言包在启动时已全部载入 [registry],
/// 这里 [load] 可同步完成,切换语言时无异步闪烁。
class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate(this.registry);

  final LanguagePackRegistry registry;

  @override
  bool isSupported(Locale locale) => true; // 总能回退,故对任意 locale 都「支持」

  @override
  Future<AppLocalizations> load(Locale locale) {
    final pack = registry.resolve(locale) ?? registry.fallback;
    assert(pack != null, '语言包注册表为空,请确认 main 中已加载语言包');
    return SynchronousFuture(
      AppLocalizations(pack!, registry.fallback),
    );
  }

  // 注册表内容可能在运行时被替换(导入外置包),故总是允许重载。
  @override
  bool shouldReload(AppLocalizationsDelegate old) => true;
}

/// 便捷扩展:`context.tr('settings.title')`。
extension AppLocalizationsX on BuildContext {
  String tr(String key, {Map<String, String>? params}) =>
      AppLocalizations.of(this).tr(key, params: params);
}
