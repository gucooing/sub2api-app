import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../i18n/locale_controller.dart';
import '../server/server_store.dart';
import '../session/session_controller.dart';
import '../storage/secure_store.dart';
import 'api_client.dart';

/// 把 Riverpod 世界桥接给 ApiClient 的令牌接口:
/// 读写当前激活服务器的令牌;刷新失败时通知会话层登出。
class _TokenBridge implements TokenProvider {
  _TokenBridge(this._ref, this._serverId);

  final Ref _ref;
  final String _serverId;

  SecureStore get _store => _ref.read(secureStoreProvider);

  @override
  Future<String?> get accessToken => _store.readAccessToken(_serverId);

  @override
  Future<String?> get refreshToken => _store.readRefreshToken(_serverId);

  @override
  Future<void> onTokensRefreshed(
      String accessToken, String? refreshToken) async {
    await _store.writeTokens(_serverId,
        accessToken: accessToken, refreshToken: refreshToken);
  }

  @override
  Future<void> onSessionExpired() async {
    await _ref
        .read(sessionControllerProvider.notifier)
        .handleSessionExpired(_serverId);
  }
}

/// 面向当前激活服务器的 ApiClient;切换服务器时自动重建。
final apiClientProvider = Provider<ApiClient>((ref) {
  final server = ref.watch(activeServerProvider);
  return ApiClient(
    origin: server.baseUrl,
    tokens: _TokenBridge(ref, server.id),
    localeTag: () => ref.read(localeControllerProvider).currentTag,
  );
});
