import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [SharedPreferences] 单例。必须在 `main` 中通过 override 注入已初始化实例,
/// 否则读取时抛错,提醒启动流程未正确装配。
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider 必须在 main 中 override'),
);

/// 本地配置键名集中管理,避免散落的魔法字符串。
class PrefKeys {
  const PrefKeys._();

  /// 用户手动选择的语言标签;为空表示「跟随系统」。
  static const String localeTag = 'pref.locale_tag';

  /// 主题模式:system / light / dark。
  static const String themeMode = 'pref.theme_mode';
}
