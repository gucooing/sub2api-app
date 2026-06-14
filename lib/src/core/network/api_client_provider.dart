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
///
/// 注意:[SecureStore] 在构造时注入具体单例实例(而非通过 ref 延迟读取),
/// 这样即使本 ApiClient 所属的 [apiClientProvider] 因切换账号被重建/销毁,
/// 仍在途的 dio 请求(拦截器读取令牌)也不会触碰已销毁的 ref。
/// 仅 [onSessionExpired] 需要会话层,通过 ref 延迟读取并以 `ref.mounted` 守卫。
class _TokenBridge implements TokenProvider {
  _TokenBridge(this._store, this._ref, this._accountId);

  final SecureStore _store;
  final Ref _ref;
  final String _accountId;

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
    // 客户端可能已随账号切换被销毁;此时新客户端会接管,旧请求静默放弃。
    if (!_ref.mounted) return;
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
  // 取生命周期稳定的具体实例(单例 / 全局 notifier),避免客户端被重建后
  // 在途请求触碰已销毁的 ref(见 _TokenBridge 说明)。
  final secure = ref.read(secureStoreProvider);
  final locale = ref.read(localeControllerProvider.notifier);
  final origin = account != null
      ? _serverById(ref, account.serverId).baseUrl
      : ref.watch(activeServerProvider).baseUrl;
  return ApiClient(
    origin: origin,
    tokens: account != null
        ? _TokenBridge(secure, ref, account.id)
        : const _NoTokenBridge(),
    localeTag: () => locale.currentTag,
  );
});

/// 面向**指定服务器**的无令牌客户端(登录页选服务器后:公开设置 + 登录)。
final serverApiClientProvider =
    Provider.family<ApiClient, ServerProfile>((ref, server) {
  final locale = ref.read(localeControllerProvider.notifier);
  return ApiClient(
    origin: server.baseUrl,
    tokens: const _NoTokenBridge(),
    localeTag: () => locale.currentTag,
  );
});
