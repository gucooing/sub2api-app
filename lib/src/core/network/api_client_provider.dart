import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../i18n/locale_controller.dart';
import '../account/account_store.dart';
import '../server/server_profile.dart';
import '../server/server_store.dart';
import '../session/session_controller.dart';
import '../storage/secure_store.dart';
import 'api_client.dart';

/// 把 Riverpod 世界桥接给 ApiClient 的令牌接口:
/// 读写某账号的令牌;刷新失败时通知会话层登出该账号。
class _TokenBridge implements TokenProvider {
  _TokenBridge(this._ref, this._accountId);

  final Ref _ref;
  final String _accountId;

  SecureStore get _store => _ref.read(secureStoreProvider);

  @override
  Future<String?> get accessToken => _store.readAccessToken(_accountId);

  @override
  Future<String?> get refreshToken => _store.readRefreshToken(_accountId);

  @override
  Future<void> onTokensRefreshed(
      String accessToken, String? refreshToken) async {
    await _store.writeTokens(_accountId,
        accessToken: accessToken, refreshToken: refreshToken);
  }

  @override
  Future<void> onSessionExpired() async {
    await _ref
        .read(sessionControllerProvider.notifier)
        .handleSessionExpired(_accountId);
  }
}

/// 无令牌桥(登录/公开设置等无需鉴权的请求,或未登录态的占位客户端)。
class _NoTokenBridge implements TokenProvider {
  const _NoTokenBridge();

  @override
  Future<String?> get accessToken async => null;

  @override
  Future<String?> get refreshToken async => null;

  @override
  Future<void> onTokensRefreshed(String accessToken, String? refreshToken) async {}

  @override
  Future<void> onSessionExpired() async {}
}

/// 在服务器列表里按 id 找服务器;找不到回退到激活服务器。
ServerProfile _serverById(Ref ref, String serverId) {
  final servers = ref.read(serverStoreProvider).servers;
  for (final s in servers) {
    if (s.id == serverId) return s;
  }
  return ref.read(activeServerProvider);
}

/// 面向**当前激活账号**的 ApiClient(令牌按账号 id);切换账号时自动重建。
/// 无激活账号时指向激活服务器、不带令牌(受保护接口会安全失败)。
final apiClientProvider = Provider<ApiClient>((ref) {
  final account = ref.watch(activeAccountProvider);
  final origin = account != null
      ? _serverById(ref, account.serverId).baseUrl
      : ref.watch(activeServerProvider).baseUrl;
  return ApiClient(
    origin: origin,
    tokens: account != null
        ? _TokenBridge(ref, account.id)
        : const _NoTokenBridge(),
    localeTag: () => ref.read(localeControllerProvider).currentTag,
  );
});

/// 面向**指定服务器**的无令牌客户端(登录页选服务器后:公开设置 + 登录)。
final serverApiClientProvider =
    Provider.family<ApiClient, ServerProfile>((ref, server) {
  return ApiClient(
    origin: server.baseUrl,
    tokens: const _NoTokenBridge(),
    localeTag: () => ref.read(localeControllerProvider).currentTag,
  );
});
