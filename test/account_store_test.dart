import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sub2api/src/core/account/account_profile.dart';
import 'package:sub2api/src/core/account/account_store.dart';
import 'package:sub2api/src/core/storage/prefs_store.dart';

Future<ProviderContainer> buildContainer() async {
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
  ]);
  addTearDown(container.dispose);
  return container;
}

AccountProfile _acc(String serverId, int userId, String email) =>
    AccountProfile(
      id: AccountProfile.deriveId(serverId, userId),
      serverId: serverId,
      userId: userId,
      email: email,
      displayName: email,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('首启无账号、未激活', () async {
    final container = await buildContainer();
    final state = container.read(accountStoreProvider);
    expect(state.accounts, isEmpty);
    expect(state.activeId, isNull);
    expect(state.active, isNull);
  });

  test('upsert 去重:同 id 更新而非重复', () async {
    final container = await buildContainer();
    final store = container.read(accountStoreProvider.notifier);

    await store.upsert(_acc('default', 1, 'a@x.com'));
    await store.upsert(_acc('default', 1, 'a2@x.com')); // 同 default:1
    final state = container.read(accountStoreProvider);
    expect(state.accounts, hasLength(1));
    expect(state.accounts.first.email, 'a2@x.com');
  });

  test('同服务器两个账号并存,可切换激活', () async {
    final container = await buildContainer();
    final store = container.read(accountStoreProvider.notifier);

    final id1 = await store.upsert(_acc('default', 1, 'a@x.com'));
    final id2 = await store.upsert(_acc('default', 2, 'b@x.com'));
    expect(container.read(accountStoreProvider).accounts, hasLength(2));

    await store.setActive(id1);
    expect(container.read(activeAccountProvider)?.email, 'a@x.com');
    await store.setActive(id2);
    expect(container.read(activeAccountProvider)?.email, 'b@x.com');
  });

  test('删除激活账号自动切到下一个,删空则未激活', () async {
    final container = await buildContainer();
    final store = container.read(accountStoreProvider.notifier);

    final id1 = await store.upsert(_acc('default', 1, 'a@x.com'));
    final id2 = await store.upsert(_acc('srv', 9, 'b@y.com'));
    await store.setActive(id2);

    await store.remove(id2);
    expect(container.read(accountStoreProvider).activeId, id1);

    await store.remove(id1);
    expect(container.read(accountStoreProvider).activeId, isNull);
    expect(container.read(accountStoreProvider).accounts, isEmpty);
  });

  test('持久化:重建容器后账号与激活项保留', () async {
    final prefs = await SharedPreferences.getInstance();
    final c1 = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
    final store = c1.read(accountStoreProvider.notifier);
    final id = await store.upsert(_acc('default', 1, 'a@x.com'));
    await store.setActive(id);
    c1.dispose();

    final c2 = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
    addTearDown(c2.dispose);
    final state = c2.read(accountStoreProvider);
    expect(state.accounts, hasLength(1));
    expect(state.activeId, id);
  });
}
