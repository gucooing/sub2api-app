import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage/prefs_store.dart';
import 'language_pack.dart';
import 'language_pack_loader.dart';
import 'language_pack_registry.dart';

/// 语言包加载器。
final languagePackLoaderProvider =
    Provider<LanguagePackLoader>((ref) => LanguagePackLoader());

/// 语言包注册表。必须在 `main` 中以已填充实例 override。
final languagePackRegistryProvider = Provider<LanguagePackRegistry>(
  (ref) => throw UnimplementedError('languagePackRegistryProvider 必须在 main 中 override'),
);

/// 语言状态:当前 locale 与语言包标签、是否跟随系统、已加载语言包列表、修订号。
///
/// [revision] 在导入/重载外置语言包后自增,用于强制依赖方重建。
@immutable
class LocaleState {
  const LocaleState({
    required this.locale,
    required this.currentTag,
    required this.followSystem,
    required this.packs,
    required this.supportedLocales,
    this.revision = 0,
  });

  final Locale locale;

  /// 当前解析到的语言包标签(如 `zh-CN`);语言选择列表以此判断选中项。
  final String? currentTag;

  final bool followSystem;
  final List<LanguagePack> packs;
  final List<Locale> supportedLocales;
  final int revision;
}

/// 管理应用语言:初始化为「已保存语言」或「系统语言」,支持运行时切换与热重载语言包。
class LocaleController extends Notifier<LocaleState> {
  /// 当前语言标签(供 ApiClient 注入 Accept-Language)。
  /// 直接读自身 state,使其在持有本 notifier 的长生命周期对象中安全可用。
  String? get currentTag => state.currentTag;

  @override
  LocaleState build() {
    final registry = ref.watch(languagePackRegistryProvider);
    final prefs = ref.watch(sharedPreferencesProvider);

    final savedTag = prefs.getString(PrefKeys.localeTag);
    if (savedTag != null && savedTag.isNotEmpty) {
      return _stateFor(registry, LanguagePack.parseLocale(savedTag),
          followSystem: false, revision: 0);
    }
    // 默认跟随系统语言(找不到匹配包时由 registry 回退)。
    return _stateFor(registry, _systemLocale(), followSystem: true, revision: 0);
  }

  LocaleState _stateFor(
    LanguagePackRegistry registry,
    Locale desired, {
    required bool followSystem,
    required int revision,
  }) {
    final resolved = registry.resolve(desired);
    return LocaleState(
      locale: resolved?.locale ?? desired,
      currentTag: resolved?.tag,
      followSystem: followSystem,
      packs: registry.all,
      supportedLocales: registry.supportedLocales,
      revision: revision,
    );
  }

  Locale _systemLocale() =>
      WidgetsBinding.instance.platformDispatcher.locale;

  /// 切换到指定语言包标签(如 `zh-CN`),并持久化选择。
  Future<void> setLocale(String tag) async {
    final registry = ref.read(languagePackRegistryProvider);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(PrefKeys.localeTag, tag);
    state = _stateFor(registry, LanguagePack.parseLocale(tag),
        followSystem: false, revision: state.revision);
  }

  /// 恢复为跟随系统语言,并清除持久化选择。
  Future<void> useSystemLocale() async {
    final registry = ref.read(languagePackRegistryProvider);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(PrefKeys.localeTag);
    state = _stateFor(registry, _systemLocale(),
        followSystem: true, revision: state.revision);
  }

  /// 重新扫描并加载外置语言包(用户投放新 .json 后调用),热更新注册表。
  Future<void> reloadPacks() async {
    final registry = ref.read(languagePackRegistryProvider);
    final loader = ref.read(languagePackLoaderProvider);
    final packs = await loader.loadAll();
    registry.replaceAll(packs, fallbackTag: loader.fallbackTag);

    final desired = state.followSystem ? _systemLocale() : state.locale;
    state = _stateFor(registry, desired,
        followSystem: state.followSystem, revision: state.revision + 1);
  }

  /// 从用户选择的文件导入语言包,成功后热更新。返回导入语言的本地名。
  Future<String> importPack(String filePath) async {
    final loader = ref.read(languagePackLoaderProvider);
    final pack = await loader.importPackFromFile(filePath);
    await reloadPacks();
    return pack.nativeName;
  }

  /// 删除一个已导入的外置语言包;若删除的是当前语言则回退到系统语言。
  Future<void> deletePack(String tag) async {
    final loader = ref.read(languagePackLoaderProvider);
    await loader.deleteExternalByTag(tag);
    if (!state.followSystem && state.currentTag == tag) {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.remove(PrefKeys.localeTag);
      await reloadPacks();
      final registry = ref.read(languagePackRegistryProvider);
      state = _stateFor(registry, _systemLocale(),
          followSystem: true, revision: state.revision);
    } else {
      await reloadPacks();
    }
  }

  /// 已导入的外置语言包标签集合(用于设置页判断哪些可删除)。
  Future<Set<String>> externalTags() async {
    final loader = ref.read(languagePackLoaderProvider);
    return (await loader.externalPackPaths()).keys.toSet();
  }
}

final localeControllerProvider =
    NotifierProvider<LocaleController, LocaleState>(LocaleController.new);
