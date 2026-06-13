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
  String _emailKey(String serverId) => 'cred.$serverId.email';
  String _passwordKey(String serverId) => 'cred.$serverId.password';

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

  // —— 登录页「记住账号/密码」凭据(按服务器分键) ——

  Future<String?> readSavedEmail(String serverId) =>
      _storage.read(key: _emailKey(serverId));

  Future<String?> readSavedPassword(String serverId) =>
      _storage.read(key: _passwordKey(serverId));

  /// 保存登录凭据。[email] 为 null 时清除账号(同时清除密码);
  /// [password] 为 null 时只记住账号、清除已存密码。
  Future<void> saveCredentials(
    String serverId, {
    required String? email,
    required String? password,
  }) async {
    if (email == null || email.isEmpty) {
      await clearCredentials(serverId);
      return;
    }
    await _storage.write(key: _emailKey(serverId), value: email);
    if (password != null && password.isNotEmpty) {
      await _storage.write(key: _passwordKey(serverId), value: password);
    } else {
      await _storage.delete(key: _passwordKey(serverId));
    }
  }

  Future<void> clearCredentials(String serverId) async {
    await _storage.delete(key: _emailKey(serverId));
    await _storage.delete(key: _passwordKey(serverId));
  }
}

final secureStoreProvider = Provider<SecureStore>((ref) => SecureStore());
