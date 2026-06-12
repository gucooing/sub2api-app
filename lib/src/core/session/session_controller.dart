import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_exception.dart';
import '../server/server_store.dart';
import '../storage/secure_store.dart';
import 'auth_api.dart';
import 'auth_models.dart';

enum SessionStatus {
  /// 启动/切换服务器后正在恢复会话。
  restoring,

  /// 未登录。
  unauthenticated,

  /// 已登录。
  authenticated,
}

@immutable
class SessionState {
  const SessionState({required this.status, this.user});

  final SessionStatus status;
  final AppUser? user;

  bool get isAuthenticated =>
      status == SessionStatus.authenticated && user != null;
  bool get isAdmin => user?.isAdmin ?? false;
}

/// 会话控制器:启动恢复、登录(含 TOTP 两步)、注册、登出。
///
/// 令牌按服务器分键保存(见 SecureStore),切换激活服务器会触发重建并
/// 针对新服务器重新恢复会话 —— 各后端登录态互不影响。
class SessionController extends Notifier<SessionState> {
  /// 防止旧的异步恢复结果覆盖新状态(如恢复期间切换了服务器)。
  int _epoch = 0;

  @override
  SessionState build() {
    final server = ref.watch(activeServerProvider);
    final epoch = ++_epoch;
    Future.microtask(() => _restore(server.id, epoch));
    return const SessionState(status: SessionStatus.restoring);
  }

  AuthApi get _api => ref.read(authApiProvider);
  SecureStore get _secure => ref.read(secureStoreProvider);
  String get _serverId => ref.read(activeServerProvider).id;

  void _set(int epoch, SessionState next) {
    // ref.mounted:容器销毁/重建后丢弃迟到的异步结果。
    if (epoch == _epoch && ref.mounted) state = next;
  }

  Future<void> _restore(String serverId, int epoch) async {
    final token = await _secure.readAccessToken(serverId);
    if (token == null || token.isEmpty) {
      _set(epoch, const SessionState(status: SessionStatus.unauthenticated));
      return;
    }
    try {
      final user = AppUser.fromJson(await _api.me());
      _set(epoch,
          SessionState(status: SessionStatus.authenticated, user: user));
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        // 令牌确认失效才清理;网络错误保留令牌,下次启动再试。
        await _secure.clearTokens(serverId);
      }
      _set(epoch, const SessionState(status: SessionStatus.unauthenticated));
    } catch (_) {
      _set(epoch, const SessionState(status: SessionStatus.unauthenticated));
    }
  }

  Future<void> _applyAuthResponse(Map<String, dynamic> data) async {
    final access = data['access_token'] as String?;
    if (access == null || access.isEmpty) {
      throw const ApiException(kind: ApiExceptionKind.business);
    }
    await _secure.writeTokens(
      _serverId,
      accessToken: access,
      refreshToken: data['refresh_token'] as String?,
    );
    final user =
        AppUser.fromJson((data['user'] as Map).cast<String, dynamic>());
    state = SessionState(status: SessionStatus.authenticated, user: user);
  }

  /// 登录第一步。返回成功或「需要 TOTP」;凭证/网络错误抛 [ApiException]。
  Future<LoginOutcome> login(String email, String password) async {
    final data = await _api.login(email, password);
    if (data['requires_2fa'] == true) {
      return LoginNeedsTotp(
        tempToken: data['temp_token'] as String? ?? '',
        maskedEmail: data['user_email_masked'] as String?,
      );
    }
    await _applyAuthResponse(data);
    return LoginSuccess(state.user!);
  }

  /// TOTP 两步验证完成登录。
  Future<void> submitTotp(String tempToken, String code) async {
    await _applyAuthResponse(await _api.login2fa(tempToken, code));
  }

  /// 注册(成功即登录)。
  Future<void> register({
    required String email,
    required String password,
    String? verifyCode,
    String? promoCode,
    String? invitationCode,
  }) async {
    final data = await _api.register(
      email: email,
      password: password,
      verifyCode: verifyCode,
      promoCode: promoCode,
      invitationCode: invitationCode,
    );
    await _applyAuthResponse(data);
  }

  /// 登出:通知后端(容错)并清理本地令牌。
  Future<void> logout() async {
    final serverId = _serverId;
    final refresh = await _secure.readRefreshToken(serverId);
    try {
      await _api.logout(refreshToken: refresh);
    } catch (_) {
      // 后端不可达也要完成本地登出
    }
    await _secure.clearTokens(serverId);
    state = const SessionState(status: SessionStatus.unauthenticated);
  }

  /// 令牌刷新失败(ApiClient 回调):本地登出。
  Future<void> handleSessionExpired(String serverId) async {
    await _secure.clearTokens(serverId);
    if (serverId == _serverId &&
        state.status == SessionStatus.authenticated) {
      state = const SessionState(status: SessionStatus.unauthenticated);
    }
  }

  /// 重新拉取当前用户(余额变动等场景)。
  Future<void> refreshUser() async {
    if (!state.isAuthenticated) return;
    final epoch = _epoch;
    try {
      final user = AppUser.fromJson(await _api.me());
      _set(epoch,
          SessionState(status: SessionStatus.authenticated, user: user));
    } on ApiException {
      // 静默失败,保留现有用户信息
    }
  }
}

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

/// 当前服务器的公开设置(登录/注册页用,无需鉴权)。
final publicSettingsProvider =
    FutureProvider.autoDispose<PublicSettingsLite>((ref) async {
  // 依赖激活服务器:切换后自动重新拉取。
  ref.watch(activeServerProvider);
  final api = ref.watch(authApiProvider);
  return PublicSettingsLite.fromJson(await api.publicSettings());
});
