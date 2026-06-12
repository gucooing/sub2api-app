import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 令牌安全存储。按服务器 ID 分键保存,支持多后端各自维持登录态。
///
/// 键形如 `token.<serverId>.access` / `token.<serverId>.refresh`。
class SecureStore {
  SecureStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  String _accessKey(String serverId) => 'token.$serverId.access';
  String _refreshKey(String serverId) => 'token.$serverId.refresh';

  Future<String?> readAccessToken(String serverId) =>
      _storage.read(key: _accessKey(serverId));

  Future<String?> readRefreshToken(String serverId) =>
      _storage.read(key: _refreshKey(serverId));

  Future<void> writeTokens(
    String serverId, {
    required String accessToken,
    String? refreshToken,
  }) async {
    await _storage.write(key: _accessKey(serverId), value: accessToken);
    if (refreshToken != null) {
      await _storage.write(key: _refreshKey(serverId), value: refreshToken);
    }
  }

  Future<void> clearTokens(String serverId) async {
    await _storage.delete(key: _accessKey(serverId));
    await _storage.delete(key: _refreshKey(serverId));
  }
}

final secureStoreProvider = Provider<SecureStore>((ref) => SecureStore());
