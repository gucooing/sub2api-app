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

  /// 服务器列表(ServerProfile JSON 数组)。
  static const String servers = 'pref.servers';

  /// 当前激活的服务器 ID。
  static const String activeServerId = 'pref.active_server_id';

  /// 已登录账号列表(AccountProfile JSON 数组)。
  static const String accounts = 'pref.accounts';

  /// 当前激活的账号 ID。
  static const String activeAccountId = 'pref.active_account_id';

  /// 登录条款已同意的修订号前缀:`pref.agreement.<serverId>` = revision。
  static const String agreementPrefix = 'pref.agreement.';

  /// 是否使用外置浏览器打开链接;false(默认)表示应用内浏览器。
  static const String externalBrowser = 'pref.external_browser';

  /// 各账号当前所处界面(用户端/管理端)。JSON map:`{accountId: "admin"}`,
  /// 缺省表示用户端。切换账号/重启后据此恢复账号上次所在的界面。
  static const String appModeByAccount = 'pref.app_mode_by_account';
}
