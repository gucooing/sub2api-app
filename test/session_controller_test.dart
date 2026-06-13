import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sub2api/src/core/account/account_profile.dart';
import 'package:sub2api/src/core/account/account_store.dart';
import 'package:sub2api/src/core/network/api_exception.dart';
import 'package:sub2api/src/core/server/server_store.dart';
import 'package:sub2api/src/core/session/auth_api.dart';
import 'package:sub2api/src/core/session/auth_models.dart';
import 'package:sub2api/src/core/session/session_controller.dart';
import 'package:sub2api/src/core/storage/prefs_store.dart';
import 'package:sub2api/src/core/storage/secure_store.dart';

/// 内存版 SecureStore(避免触发平台通道)。键参数语义现为账号 id。
class MemorySecureStore extends SecureStore {
  final Map<String, String> data = {};

  @override
  Future<String?> readAccessToken(String accountId) async =>
      data['$accountId.access'];

  @override
  Future<String?> readRefreshToken(String accountId) async =>
      data['$accountId.refresh'];

  @override
  Future<void> writeTokens(String accountId,
      {required String accessToken, String? refreshToken}) async {
    data['$accountId.access'] = accessToken;
    if (refreshToken != null) data['$accountId.refresh'] = refreshToken;
  }

  @override
  Future<void> clearTokens(String accountId) async {
    data.remove('$accountId.access');
    data.remove('$accountId.refresh');
  }
}

class FakeAuthApi implements AuthApi {
  Map<String, dynamic> Function(String email, String password)? onLogin;
  Map<String, dynamic>? meResponse;
  Object? meError;
  int logoutCalls = 0;

  static Map<String, dynamic> userJson({String role = 'user', int id = 1}) => {
        'id': id,
        'username': 'sam',
        'email': 'sam@x.com',
        'role': role,
        'balance': 12.5,
        'concurrency': 5,
        'status': 'active',
        'created_at': '2026-01-01T00:00:00Z',
      };

  @override
  Future<Map<String, dynamic>> login(String email, String password,
          {String? turnstileToken}) async =>
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
  Future<Map<String, dynamic>> forgotPassword(String email,
          {String? turnstileToken}) async =>
      {'message': 'sent'};

  @override
  Future<Map<String, dynamic>> publicSettings() async => {
        'registration_enabled': true,
        'email_verify_enabled': false,
        'turnstile_enabled': false,
      };
}

/// 预置已激活账号到 prefs(模拟启动时已有登录账号)。
void seedActiveAccount() {
  final account = AccountProfile(
    id: AccountProfile.deriveId('default', 1),
    serverId: 'default',
    userId: 1,
    email: 'sam@x.com',
    displayName: 'sam',
  );
  SharedPreferences.setMockInitialValues({
    PrefKeys.accounts: jsonEncode([account.toJson()]),
    PrefKeys.activeAccountId: account.id,
  });
}

Future<ProviderContainer> containerWithPrefs(
    FakeAuthApi api, MemorySecureStore secure) async {
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    secureStoreProvider.overrideWithValue(secure),
    authApiProvider.overrideWithValue(api),
    authApiForServerProvider.overrideWith((ref, server) => api),
  ]);
  addTearDown(container.dispose);
  // 保持订阅:provider 立即初始化,且依赖变化时立刻重建。
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
    expect(s.paymentEnabled, isFalse);
    expect(s.affiliateEnabled, isFalse);
    expect(s.customMenuItems, isEmpty);
  });

  test('PublicSettingsLite 解析登录条款', () {
    final s = PublicSettingsLite.fromJson({
      'login_agreement_enabled': true,
      'login_agreement_mode': 'checkbox',
      'login_agreement_revision': 'v3',
      'login_agreement_documents': [
        {'id': 'tos', 'title': '服务条款', 'content_md': '# TOS'},
        {'id': 'empty', 'title': '  ', 'content_md': 'x'},
      ],
    });
    expect(s.loginAgreementEnabled, isTrue);
    expect(s.loginAgreementMode, 'checkbox');
    expect(s.loginAgreementRevision, 'v3');
    expect(s.agreementDocuments, hasLength(1)); // 空标题被过滤
    expect(s.agreementGateActive, isTrue);
  });

  test('登录条款 revision 回退到 updated_at', () {
    final s = PublicSettingsLite.fromJson({
      'login_agreement_enabled': true,
      'login_agreement_updated_at': '2026-06-01',
      'login_agreement_documents': [
        {'id': 'tos', 'title': 'TOS', 'content_md': 'x'},
      ],
    });
    expect(s.loginAgreementRevision, '2026-06-01');
  });

  test('无激活账号:恢复为未登录', () async {
    final api = FakeAuthApi();
    final secure = MemorySecureStore();
    final c = await containerWithPrefs(api, secure);
    await pump();
    expect(c.read(sessionControllerProvider).status,
        SessionStatus.unauthenticated);
  });

  test('有激活账号 + 令牌:me 成功→已登录;401→清令牌未登录', () async {
    seedActiveAccount();
    final api = FakeAuthApi();
    final secure = MemorySecureStore();
    secure.data['default:1.access'] = 'tok';
    var c = await containerWithPrefs(api, secure);
    await pump();
    expect(c.read(sessionControllerProvider).isAuthenticated, isTrue);
    expect(c.read(sessionControllerProvider).user!.email, 'sam@x.com');

    // 401 失效
    seedActiveAccount();
    final secure2 = MemorySecureStore();
    secure2.data['default:1.access'] = 'bad';
    final api2 = FakeAuthApi()
      ..meError =
          const ApiException(kind: ApiExceptionKind.http, statusCode: 401);
    c = await containerWithPrefs(api2, secure2);
    await pump();
    expect(c.read(sessionControllerProvider).status,
        SessionStatus.unauthenticated);
    expect(secure2.data.containsKey('default:1.access'), isFalse);
  });

  test('登录成功:建账号、写令牌、激活、已登录', () async {
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

    final server = c.read(activeServerProvider);
    final outcome = await c
        .read(sessionControllerProvider.notifier)
        .login(server, 'sam@x.com', 'pw');

    expect(outcome, isA<LoginSuccess>());
    expect(secure.data['default:1.access'], 'a1');
    expect(secure.data['default:1.refresh'], 'r1');
    expect(c.read(sessionControllerProvider).isAuthenticated, isTrue);
    expect(c.read(activeAccountProvider)?.id, 'default:1');
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
    final server = c.read(activeServerProvider);

    final outcome = await notifier.login(server, 'sam@x.com', 'pw');
    expect(outcome, isA<LoginNeedsTotp>());
    expect((outcome as LoginNeedsTotp).tempToken, 'tmp1');
    expect(c.read(sessionControllerProvider).isAuthenticated, isFalse);

    await notifier.submitTotp(server, 'tmp1', '123456');
    expect(c.read(sessionControllerProvider).isAuthenticated, isTrue);
    expect(secure.data['default:1.access'], 'a2');
  });

  test('登出:调用后端、清令牌、移除账号、回到未登录', () async {
    seedActiveAccount();
    final api = FakeAuthApi();
    final secure = MemorySecureStore();
    secure.data['default:1.access'] = 'tok';
    secure.data['default:1.refresh'] = 'ref';
    final c = await containerWithPrefs(api, secure);
    await pump();
    expect(c.read(sessionControllerProvider).isAuthenticated, isTrue);

    await c.read(sessionControllerProvider.notifier).logout();

    expect(api.logoutCalls, 1);
    expect(secure.data, isEmpty);
    expect(c.read(accountStoreProvider).accounts, isEmpty);
    expect(c.read(sessionControllerProvider).status,
        SessionStatus.unauthenticated);
  });

  test('账号切换:切到无令牌账号→未登录,切回→已登录', () async {
    seedActiveAccount();
    final api = FakeAuthApi();
    final secure = MemorySecureStore();
    secure.data['default:1.access'] = 'tok';
    final c = await containerWithPrefs(api, secure);
    await pump();
    expect(c.read(sessionControllerProvider).isAuthenticated, isTrue);

    // 新增一个无令牌的账号并切换 → 未登录
    final accounts = c.read(accountStoreProvider.notifier);
    const other = AccountProfile(
      id: 'srv:2',
      serverId: 'srv',
      userId: 2,
      email: 'b@y.com',
      displayName: 'b',
    );
    await accounts.upsert(other);
    await accounts.setActive('srv:2');
    await pump();
    expect(c.read(sessionControllerProvider).status,
        SessionStatus.unauthenticated);

    // 切回有令牌的账号 → 已登录
    await accounts.setActive('default:1');
    await pump();
    expect(c.read(sessionControllerProvider).isAuthenticated, isTrue);
  });
}
