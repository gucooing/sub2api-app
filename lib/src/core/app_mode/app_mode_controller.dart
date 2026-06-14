import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../account/account_store.dart';
import '../storage/prefs_store.dart';

/// 应用界面模式:用户端 / 管理端。
///
/// 管理端是「另一套主界面」(独立底部导航与页面);切换以账号为单位记忆,
/// 切换账号或重启后恢复该账号上次所在的界面。
enum AppMode {
  user,
  admin;

  String get storageValue => name;

  static AppMode fromStorage(String? v) =>
      v == AppMode.admin.name ? AppMode.admin : AppMode.user;
}

/// 当前激活账号所处的界面模式(以账号为单位持久化)。
///
/// 状态随激活账号变化自动重算:`build()` 监听 [activeAccountProvider],
/// 切换账号即返回新账号记忆的模式(默认用户端)。
class AppModeController extends Notifier<AppMode> {
  @override
  AppMode build() {
    final account = ref.watch(activeAccountProvider);
    if (account == null) return AppMode.user;
    return _readMap()[account.id] ?? AppMode.user;
  }

  Map<String, AppMode> _readMap() {
    final prefs = ref.read(sharedPreferencesProvider);
    final raw = prefs.getString(PrefKeys.appModeByAccount);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map(
        (k, v) => MapEntry('$k', AppMode.fromStorage(v as String?)),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> _persist(Map<String, AppMode> map) async {
    final prefs = ref.read(sharedPreferencesProvider);
    // 仅持久化非默认(admin)项,保持存储精简。
    final entries = <String, String>{
      for (final e in map.entries)
        if (e.value == AppMode.admin) e.key: e.value.storageValue,
    };
    if (entries.isEmpty) {
      await prefs.remove(PrefKeys.appModeByAccount);
    } else {
      await prefs.setString(PrefKeys.appModeByAccount, jsonEncode(entries));
    }
  }

  /// 设置当前激活账号的界面模式并持久化。无激活账号时仅更新内存状态。
  Future<void> setMode(AppMode mode) async {
    state = mode;
    final account = ref.read(activeAccountProvider);
    if (account == null) return;
    final map = _readMap()..[account.id] = mode;
    await _persist(map);
  }

  /// 在用户端/管理端之间切换。
  Future<void> toggle() =>
      setMode(state == AppMode.admin ? AppMode.user : AppMode.admin);
}

final appModeControllerProvider =
    NotifierProvider<AppModeController, AppMode>(AppModeController.new);

/// 给定账号 id 的记忆模式(直接读 prefs,无需激活账号),供切换账号时判断落地界面。
AppMode appModeForAccount(SharedPreferences prefs, String? accountId) {
  if (accountId == null) return AppMode.user;
  final raw = prefs.getString(PrefKeys.appModeByAccount);
  if (raw == null || raw.isEmpty) return AppMode.user;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return AppMode.user;
    return AppMode.fromStorage(decoded[accountId] as String?);
  } catch (_) {
    return AppMode.user;
  }
}
