import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sub2api/src/core/network/api_exception.dart';
import 'package:sub2api/src/core/server/server_store.dart';
import 'package:sub2api/src/core/session/auth_api.dart';
import 'package:sub2api/src/core/session/auth_models.dart';
import 'package:sub2api/src/core/session/session_controller.dart';
import 'package:sub2api/src/core/storage/prefs_store.dart';
import 'package:sub2api/src/core/storage/secure_store.dart';

/// 内存版 SecureStore(避免触发平台通道)。
class MemorySecureStore extends SecureStore {
  final Map<String, String> data = {};

  @override
  Future<String?> readAccessToken(String serverId) async =>
      data['$serverId.access'];

  @override
  Future<String?> readRefreshToken(String serverId) async =>
      data['$serverId.refresh'];

  @override
  Future<void> writeTokens(String serverId,
      {required String accessToken, String? refreshToken}) async {
    data['$serverId.access'] = accessToken;
    if (refreshToken != null) data['$serverId.refresh'] = refreshToken;
  }

  @override
  Future<void> clearTokens(String serverId) async {
    data.remove('$serverId.access');
    data.remove('$serverId.refresh');
  }
}

class FakeAuthApi implements AuthApi {
  Map<String, dynamic> Function(String email, String password)? onLogin;
  Map<String, dynamic>? meResponse;
  Object? meError;
  int logoutCalls = 0;

  static Map<String, dynamic> userJson({String role = 'user'}) => {
        'id': 1,
        'username': 'sam',
        'email': 'sam@x.com',
        'role': role,
        'balance': 12.5,
        'concurrency': 5,
        'status': 'active',
        'created_at': '2026-01-01T00:00:00Z',
      };

  @override
  Future<Map<String, dynamic>> login(String email, String password) async =>
      onLogin!(email, password);

  @override
  Future<Map<String, dynamic>> login2fa(String tempToken, String code) async =>
      {
        'access_token': 'a2',
        'refresh_token': 'r2',
        'token_type': 'Bearer',
        'user': userJson(),
      };

  @override
  Future<Map<String, dynamic>> register(
          {required String email,
          required String password,
          String? verifyCode,
          String? promoCode,
          String? invitationCode}) async =>
      {
        'access_token': 'a3',
        'token_type': 'Bearer',
        'user': userJson(),
      };

  @override
  Future<Map<String, dynamic>> me() async {
    if (meError != null) throw meError!;
    return meResponse ?? userJson();
  }

  @override
  Future<void> logout({String? refreshToken}) async {
    logoutCalls++;
  }

  @override
  Future<Map<String, dynamic>> sendVerifyCode(String email) async =>
      {'message': 'ok', 'countdown': 60};

  @override
  Future<Map<String, dynamic>> publicSettings() async => {
        'registration_enabled': true,
        'email_verify_enabled': false,
        'turnstile_enabled': false,
      };
}

(ProviderContainer, FakeAuthApi, MemorySecureStore) buildContainer() {
  final api = FakeAuthApi();
  final secure = MemorySecureStore();
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWith((ref) {
      throw UnimplementedError(); // 由下方真实实例覆盖
    }),
    secureStoreProvider.overrideWithValue(secure),
    authApiProvider.overrideWithValue(api),
  ]);
  return (container, api, secure);
}

Future<ProviderContainer> containerWithPrefs(
    FakeAuthApi api, MemorySecureStore secure) async {
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    secureStoreProvider.overrideWithValue(secure),
    authApiProvider.overrideWithValue(api),
  ]);
  addTearDown(container.dispose);
  // 保持订阅:provider 立即初始化,且依赖(激活服务器)变化时立刻重建。
  container.listen(sessionControllerProvider, (_, _) {});
  return container;
}

Future<void> pump() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('AppUser/PublicSettingsLite 解析', () {
    final user = AppUser.fromJson(FakeAuthApi.userJson(role: 'admin'));
    expect(user.isAdmin, isTrue);
    expect(user.balance, 12.5);
    expect(user.createdAt, isNotNull);

    final s = PublicSettingsLite.fromJson(
        {'registration_enabled': true, 'turnstile_enabled': true});
    expect(s.registrationEnabled, isTrue);
    expect(s.turnstileEnabled, isTrue);
    expect(s.emailVerifyEnabled, isFalse);
    // 功能开关与自定义页面默认关闭/为空。
    expect(s.paymentEnabled, isFalse);
    expect(s.affiliateEnabled, isFalse);
    expect(s.customMenuItems, isEmpty);
  });

  test('PublicSettingsLite 解析功能开关与自定义页面', () {
    final s = PublicSettingsLite.fromJson({
      'payment_enabled': true,
      'affiliate_enabled': true,
      'available_channels_enabled': true,
      'channel_monitor_enabled': true,
      'custom_menu_items': [
        {
          'id': 'docs',
          'label': '文档',
          'url': 'https://example.com/docs',
          'visibility': 'user',
          'sort_order': 2,
        },
        {
          'id': 'guide',
          'label': '指南',
          'page_slug': 'guide',
          'visibility': 'user',
          'sort_order': 1,
        },
        {
          'id': 'secret',
          'label': '管理',
          'url': 'https://example.com/admin',
          'visibility': 'admin',
          'sort_order': 0,
        },
      ],
    });
    expect(s.paymentEnabled, isTrue);
    expect(s.affiliateEnabled, isTrue);
    expect(s.availableChannelsEnabled, isTrue);
    expect(s.channelMonitorEnabled, isTrue);
    expect(s.customMenuItems.length, 3);

    final external = s.customMenuItems.firstWhere((e) => e.id == 'docs');
    expect(external.isMarkdown, isFalse);
    final md = s.customMenuItems.firstWhere((e) => e.id == 'guide');
    expect(md.isMarkdown, isTrue);
  });

  test('无令牌:恢复为未登录', () async {
    final api = FakeAuthApi();
    final secure = MemorySecureStore();
    final c = await containerWithPrefs(api, secure);

    expect(c.read(sessionControllerProvider).status, SessionStatus.restoring);
    await pump();
    expect(c.read(sessionControllerProvider).status,
        SessionStatus.unauthenticated);
  });

  test('有令牌:me 成功 → 已登录;401 → 清令牌未登录', () async {
    final api = FakeAuthApi();
    final secure = MemorySecureStore();
    secure.data['default.access'] = 'tok';
    var c = await containerWithPrefs(api, secure);
    await pump();
    expect(c.read(sessionControllerProvider).isAuthenticated, isTrue);
    expect(c.read(sessionControllerProvider).user!.email, 'sam@x.com');

    // 401 失效场景
    secure.data['default.access'] = 'bad';
    api.meError = const ApiException(
        kind: ApiExceptionKind.http, statusCode: 401);
    c = await containerWithPrefs(api, secure);
    await pump();
    expect(c.read(sessionControllerProvider).status,
        SessionStatus.unauthenticated);
    expect(secure.data.containsKey('default.access'), isFalse);
  });

  test('登录成功:写令牌并进入已登录', () async {
    final api = FakeAuthApi();
    api.onLogin = (e, p) => {
          'access_token': 'a1',
          'refresh_token': 'r1',
          'token_type': 'Bearer',
          'user': FakeAuthApi.userJson(),
        };
    final secure = MemorySecureStore();
    final c = await containerWithPrefs(api, secure);
    await pump();

    final outcome = await c
        .read(sessionControllerProvider.notifier)
        .login('sam@x.com', 'pw');

    expect(outcome, isA<LoginSuccess>());
    expect(secure.data['default.access'], 'a1');
    expect(secure.data['default.refresh'], 'r1');
    expect(c.read(sessionControllerProvider).isAuthenticated, isTrue);
  });

  test('登录需要 TOTP:返回挑战且保持未登录,二步后登录', () async {
    final api = FakeAuthApi();
    api.onLogin = (e, p) => {
          'requires_2fa': true,
          'temp_token': 'tmp1',
          'user_email_masked': 's***@x.com',
        };
    final secure = MemorySecureStore();
    final c = await containerWithPrefs(api, secure);
    await pump();
    final notifier = c.read(sessionControllerProvider.notifier);

    final outcome = await notifier.login('sam@x.com', 'pw');
    expect(outcome, isA<LoginNeedsTotp>());
    expect((outcome as LoginNeedsTotp).tempToken, 'tmp1');
    expect(c.read(sessionControllerProvider).isAuthenticated, isFalse);

    await notifier.submitTotp('tmp1', '123456');
    expect(c.read(sessionControllerProvider).isAuthenticated, isTrue);
    expect(secure.data['default.access'], 'a2');
  });

  test('登出:调用后端、清令牌、回到未登录', () async {
    final api = FakeAuthApi();
    final secure = MemorySecureStore();
    secure.data['default.access'] = 'tok';
    secure.data['default.refresh'] = 'ref';
    final c = await containerWithPrefs(api, secure);
    await pump();
    expect(c.read(sessionControllerProvider).isAuthenticated, isTrue);

    await c.read(sessionControllerProvider.notifier).logout();

    expect(api.logoutCalls, 1);
    expect(secure.data, isEmpty);
    expect(c.read(sessionControllerProvider).status,
        SessionStatus.unauthenticated);
  });

  test('切换服务器:各自独立的登录态', () async {
    final api = FakeAuthApi();
    final secure = MemorySecureStore();
    secure.data['default.access'] = 'tok'; // 仅默认服务器已登录
    final c = await containerWithPrefs(api, secure);
    await pump();
    expect(c.read(sessionControllerProvider).isAuthenticated, isTrue);

    // 新增并切换到备用服务器 → 未登录
    final serverStore = c.read(serverStoreProvider.notifier);
    final id = await serverStore.add('b', 'https://b.example.com');
    await serverStore.setActive(id!);
    await pump();
    expect(c.read(sessionControllerProvider).status,
        SessionStatus.unauthenticated);

    // 切回默认服务器 → 恢复已登录
    await serverStore.setActive('default');
    await pump();
    expect(c.read(sessionControllerProvider).isAuthenticated, isTrue);
  });
}
