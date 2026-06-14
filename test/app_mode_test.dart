import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sub2api/src/core/account/account_profile.dart';
import 'package:sub2api/src/core/account/account_store.dart';
import 'package:sub2api/src/core/app_mode/app_mode_controller.dart';
import 'package:sub2api/src/core/storage/prefs_store.dart';

AccountProfile _acc(String serverId, int userId, String email,
        {bool isAdmin = false}) =>
    AccountProfile(
      id: AccountProfile.deriveId(serverId, userId),
      serverId: serverId,
      userId: userId,
      email: email,
      displayName: email,
      isAdmin: isAdmin,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('默认用户端;无账号时 setMode 仅更新内存', () async {
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(c.dispose);

    expect(c.read(appModeControllerProvider), AppMode.user);
    await c.read(appModeControllerProvider.notifier).setMode(AppMode.admin);
    expect(c.read(appModeControllerProvider), AppMode.admin);
    // 无激活账号:不写持久化。
    expect(prefs.getString(PrefKeys.appModeByAccount), isNull);
  });

  test('以账号为单位记忆:切换账号后模式各自独立', () async {
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(c.dispose);

    final store = c.read(accountStoreProvider.notifier);
    final id1 = await store.upsert(_acc('default', 1, 'a@x.com', isAdmin: true));
    final id2 = await store.upsert(_acc('default', 2, 'b@x.com', isAdmin: true));

    await store.setActive(id1);
    await c.read(appModeControllerProvider.notifier).setMode(AppMode.admin);
    expect(c.read(appModeControllerProvider), AppMode.admin);

    // 切到账号 2:默认仍是用户端。
    await store.setActive(id2);
    expect(c.read(appModeControllerProvider), AppMode.user);

    // 切回账号 1:恢复其管理端记忆。
    await store.setActive(id1);
    expect(c.read(appModeControllerProvider), AppMode.admin);
  });

  test('appModeForAccount 直接读 prefs;持久化跨容器保留', () async {
    final prefs = await SharedPreferences.getInstance();
    final c1 = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    final store = c1.read(accountStoreProvider.notifier);
    final id = await store.upsert(_acc('default', 1, 'a@x.com', isAdmin: true));
    await store.setActive(id);
    await c1.read(appModeControllerProvider.notifier).setMode(AppMode.admin);
    c1.dispose();

    expect(appModeForAccount(prefs, id), AppMode.admin);
    expect(appModeForAccount(prefs, 'default:999'), AppMode.user);
    expect(appModeForAccount(prefs, null), AppMode.user);

    // 重建容器:激活账号的模式仍为管理端。
    final c2 = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(c2.dispose);
    expect(c2.read(appModeControllerProvider), AppMode.admin);
  });

  test('切回用户端会清除该账号的持久化(仅存 admin 项)', () async {
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(c.dispose);

    final store = c.read(accountStoreProvider.notifier);
    final id = await store.upsert(_acc('default', 1, 'a@x.com', isAdmin: true));
    await store.setActive(id);

    final ctrl = c.read(appModeControllerProvider.notifier);
    await ctrl.setMode(AppMode.admin);
    expect(prefs.getString(PrefKeys.appModeByAccount), isNotNull);

    await ctrl.setMode(AppMode.user);
    // 默认项不持久化 → 整个键被清除。
    expect(prefs.getString(PrefKeys.appModeByAccount), isNull);
    expect(appModeForAccount(prefs, id), AppMode.user);
  });
}
