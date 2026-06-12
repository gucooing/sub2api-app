import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sub2api/src/core/server/server_profile.dart';
import 'package:sub2api/src/core/server/server_store.dart';
import 'package:sub2api/src/core/storage/prefs_store.dart';

Future<(ProviderContainer, SharedPreferences)> buildContainer() async {
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
  ]);
  addTearDown(container.dispose);
  return (container, prefs);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('normalizeBaseUrl:去斜杠、校验 scheme/host', () {
    expect(ServerProfile.normalizeBaseUrl(' https://ai.alsl.xyz/ '),
        'https://ai.alsl.xyz');
    expect(ServerProfile.normalizeBaseUrl('http://10.0.0.2:8080//'),
        'http://10.0.0.2:8080');
    expect(ServerProfile.normalizeBaseUrl('ftp://x.com'), isNull);
    expect(ServerProfile.normalizeBaseUrl('not a url'), isNull);
  });

  test('首启注入内置默认服务器并激活', () async {
    final (container, _) = await buildContainer();
    final state = container.read(serverStoreProvider);

    expect(state.servers, hasLength(1));
    expect(state.active.builtIn, isTrue);
    expect(state.active.baseUrl, 'https://ai.alsl.xyz');
  });

  test('add/setActive/remove 并持久化', () async {
    final (container, prefs) = await buildContainer();
    final store = container.read(serverStoreProvider.notifier);

    final id = await store.add('自建', 'https://my.example.com/');
    expect(id, isNotNull);
    expect(container.read(serverStoreProvider).servers, hasLength(2));

    await store.setActive(id!);
    expect(container.read(serverStoreProvider).active.name, '自建');
    expect(prefs.getString(PrefKeys.activeServerId), id);

    // 激活中的服务器不可删除
    expect(await store.remove(id), isFalse);
    await store.setActive('default');
    expect(await store.remove(id), isTrue);
    expect(container.read(serverStoreProvider).servers, hasLength(1));

    // 内置项不可删除
    expect(await store.remove('default'), isFalse);
  });

  test('非法 baseUrl 拒绝添加;内置项只能改名', () async {
    final (container, _) = await buildContainer();
    final store = container.read(serverStoreProvider.notifier);

    expect(await store.add('x', 'nope'), isNull);

    await store.update('default', name: '官方', baseUrl: 'https://evil.com');
    final builtIn = container.read(serverStoreProvider).active;
    expect(builtIn.name, '官方');
    expect(builtIn.baseUrl, 'https://ai.alsl.xyz'); // 地址未被改动
  });

  test('重建后从持久化恢复', () async {
    final (container, prefs) = await buildContainer();
    final store = container.read(serverStoreProvider.notifier);
    final id = await store.add('备用', 'https://b.example.com');
    await store.setActive(id!);

    // 用同一 prefs 新建容器,模拟应用重启
    final container2 = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
    addTearDown(container2.dispose);
    final state = container2.read(serverStoreProvider);
    expect(state.servers, hasLength(2));
    expect(state.active.name, '备用');
  });
}
