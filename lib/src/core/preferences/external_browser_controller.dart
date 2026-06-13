import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/prefs_store.dart';

/// 「打开链接是否用外置浏览器」开关。
///
/// false(默认)= 应用内浏览器(自动携带登录态,免二次登录);
/// true = 调用系统外置浏览器。
class ExternalBrowserController extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(PrefKeys.externalBrowser) ?? false;
  }

  Future<void> set(bool value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(PrefKeys.externalBrowser, value);
    state = value;
  }
}

final externalBrowserProvider =
    NotifierProvider<ExternalBrowserController, bool>(
        ExternalBrowserController.new);
