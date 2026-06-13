import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 令牌安全存储。
///
/// 令牌按**账号 id** 分键保存,支持同一服务器多个账号各自维持登录态;
/// 键形如 `token.<accountId>.access` / `token.<accountId>.refresh`。
/// 键格式与旧版「按服务器 id」一致,故旧令牌可用同一组方法读取以做迁移。
///
/// 「记住账号/密码」凭据仍按**服务器 id** 分键(登录页选服务器即可预填,与账号无关)。
class SecureStore {
  SecureStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  String _accessKey(String accountId) => 'token.$accountId.access';
  String _refreshKey(String accountId) => 'token.$accountId.refresh';
  String _emailKey(String serverId) => 'cred.$serverId.email';
  String _passwordKey(String serverId) => 'cred.$serverId.password';

  Future<String?> readAccessToken(String accountId) =>
      _storage.read(key: _accessKey(accountId));

  Future<String?> readRefreshToken(String accountId) =>
      _storage.read(key: _refreshKey(accountId));

  Future<void> writeTokens(
    String accountId, {
    required String accessToken,
    String? refreshToken,
  }) async {
    await _storage.write(key: _accessKey(accountId), value: accessToken);
    if (refreshToken != null) {
      await _storage.write(key: _refreshKey(accountId), value: refreshToken);
    }
  }

  Future<void> clearTokens(String accountId) async {
    await _storage.delete(key: _accessKey(accountId));
    await _storage.delete(key: _refreshKey(accountId));
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
