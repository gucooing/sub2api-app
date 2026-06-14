import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../account/account_profile.dart';
import '../account/account_store.dart';
import '../network/api_exception.dart';
import '../server/server_profile.dart';
import '../storage/secure_store.dart';
import 'auth_api.dart';
import 'auth_models.dart';

enum SessionStatus {
  /// 启动/切换账号后正在恢复会话。
  restoring,

  /// 未登录(无激活账号)。
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

/// 会话控制器:以**账号**为单位。
///
/// 令牌按账号 id 保存(见 SecureStore);切换激活账号触发重建并恢复该账号会话。
/// 同一服务器的多个账号互不影响。登录/注册需指定目标服务器(登录页选择)。
class SessionController extends Notifier<SessionState> {
  /// 防止迟到的异步恢复结果覆盖新状态(如恢复期间切换了账号)。
  int _epoch = 0;

  /// 已验证登录的用户与其账号 id(供 build 在切回时免重复 me())。
  AppUser? _user;
  String? _userAccountId;

  @override
  SessionState build() {
    final account = ref.watch(activeAccountProvider);
    final epoch = ++_epoch;
    if (account == null) {
      _user = null;
      _userAccountId = null;
      return const SessionState(status: SessionStatus.unauthenticated);
    }
    // 本会话内已验证过该账号(登录后/切回):直接复用,避免闪烁与重复 me()。
    if (_userAccountId == account.id && _user != null) {
      return SessionState(status: SessionStatus.authenticated, user: _user);
    }
    Future.microtask(() => _restore(account, epoch));
    return const SessionState(status: SessionStatus.restoring);
  }

  AuthApi get _api => ref.read(authApiProvider);
  SecureStore get _secure => ref.read(secureStoreProvider);
  AccountStore get _accounts => ref.read(accountStoreProvider.notifier);

  void _set(int epoch, SessionState next) {
    if (epoch == _epoch && ref.mounted) state = next;
  }

  Future<void> _restore(AccountProfile account, int epoch) async {
    final token = await _secure.readAccessToken(account.id);
    if (token == null || token.isEmpty) {
      _set(epoch, const SessionState(status: SessionStatus.unauthenticated));
      return;
    }
    try {
      final user = AppUser.fromJson(await _api.me());
      _user = user;
      _userAccountId = account.id;
      _set(epoch,
          SessionState(status: SessionStatus.authenticated, user: user));
      // 回填账号档案最新信息(角色/邮箱/头像),供账号列表展示管理员标识等。
      if (account.isAdmin != user.isAdmin ||
          account.email != user.email ||
          account.avatarUrl != user.avatarUrl) {
        await _accounts.upsert(account.copyWith(
          isAdmin: user.isAdmin,
          email: user.email,
          avatarUrl: user.avatarUrl,
        ));
      }
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        // 令牌确认失效才清理;网络错误保留令牌,下次再试。
        await _secure.clearTokens(account.id);
      }
      _set(epoch, const SessionState(status: SessionStatus.unauthenticated));
    } catch (_) {
      _set(epoch, const SessionState(status: SessionStatus.unauthenticated));
    }
  }

  /// 处理登录/注册响应:建账号、写令牌、激活并置为已登录。
  Future<void> _applyAuthResponse(
      ServerProfile server, Map<String, dynamic> data) async {
    final access = data['access_token'] as String?;
    if (access == null || access.isEmpty) {
      throw const ApiException(kind: ApiExceptionKind.business);
    }
    final user =
        AppUser.fromJson((data['user'] as Map).cast<String, dynamic>());
    final accountId = AccountProfile.deriveId(server.id, user.id);
    await _secure.writeTokens(
      accountId,
      accessToken: access,
      refreshToken: data['refresh_token'] as String?,
    );
    final account = AccountProfile(
      id: accountId,
      serverId: server.id,
      userId: user.id,
      email: user.email,
      displayName: user.username.isNotEmpty ? user.username : user.email,
      avatarUrl: user.avatarUrl,
      isAdmin: user.isAdmin,
    );
    _user = user;
    _userAccountId = accountId;
    // 先置态再激活:setActive 触发的重建会因 _userAccountId 命中而直接返回已登录。
    state = SessionState(status: SessionStatus.authenticated, user: user);
    await _accounts.upsert(account);
    await _accounts.setActive(accountId);
  }

  /// 登录第一步(指定目标服务器)。返回成功或「需要 TOTP」。
  Future<LoginOutcome> login(
      ServerProfile server, String email, String password,
      {String? turnstileToken}) async {
    final api = ref.read(authApiForServerProvider(server));
    final data =
        await api.login(email, password, turnstileToken: turnstileToken);
    if (data['requires_2fa'] == true) {
      return LoginNeedsTotp(
        tempToken: data['temp_token'] as String? ?? '',
        maskedEmail: data['user_email_masked'] as String?,
      );
    }
    await _applyAuthResponse(server, data);
    return LoginSuccess(_user!);
  }

  /// TOTP 两步验证完成登录(指定目标服务器)。
  Future<void> submitTotp(
      ServerProfile server, String tempToken, String code) async {
    final api = ref.read(authApiForServerProvider(server));
    await _applyAuthResponse(server, await api.login2fa(tempToken, code));
  }

  /// 注册(成功即登录,指定目标服务器)。
  Future<void> register(
    ServerProfile server, {
    required String email,
    required String password,
    String? verifyCode,
    String? promoCode,
    String? invitationCode,
  }) async {
    final api = ref.read(authApiForServerProvider(server));
    final data = await api.register(
      email: email,
      password: password,
      verifyCode: verifyCode,
      promoCode: promoCode,
      invitationCode: invitationCode,
    );
    await _applyAuthResponse(server, data);
  }

  /// 切换激活账号(会触发重建并恢复目标账号会话)。
  Future<void> switchAccount(String accountId) =>
      _accounts.setActive(accountId);

  /// 登出当前激活账号:通知后端(容错)、清令牌、从列表移除(自动切换/置空)。
  Future<void> logout() async {
    final account = ref.read(activeAccountProvider);
    if (account == null) return;
    final refresh = await _secure.readRefreshToken(account.id);
    try {
      await _api.logout(refreshToken: refresh);
    } catch (_) {
      // 后端不可达也要完成本地登出
    }
    await _removeAccountInternal(account.id);
  }

  /// 删除指定账号(可为非激活账号)。
  Future<void> removeAccount(String accountId) =>
      _removeAccountInternal(accountId);

  Future<void> _removeAccountInternal(String accountId) async {
    await _secure.clearTokens(accountId);
    if (_userAccountId == accountId) {
      _user = null;
      _userAccountId = null;
    }
    await _accounts.remove(accountId);
  }

  /// 令牌刷新失败(ApiClient 回调):清该账号令牌;若是激活账号则置未登录。
  Future<void> handleSessionExpired(String accountId) async {
    await _secure.clearTokens(accountId);
    final active = ref.read(activeAccountProvider);
    if (active?.id == accountId) {
      _user = null;
      _userAccountId = null;
      if (state.status == SessionStatus.authenticated) {
        state = const SessionState(status: SessionStatus.unauthenticated);
      }
    }
  }

  /// 重新拉取当前用户(余额变动等场景)。
  Future<void> refreshUser() async {
    if (!state.isAuthenticated) return;
    final epoch = _epoch;
    try {
      final user = AppUser.fromJson(await _api.me());
      _user = user;
      _set(epoch,
          SessionState(status: SessionStatus.authenticated, user: user));
    } on ApiException {
      // 静默失败,保留现有用户信息
    }
  }
}

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

/// 当前激活账号所在服务器的公开设置(应用内使用,如绑定/功能开关)。
final publicSettingsProvider =
    FutureProvider.autoDispose<PublicSettingsLite>((ref) async {
  // 依赖激活账号:切换后自动重新拉取。
  ref.watch(activeAccountProvider);
  final api = ref.watch(authApiProvider);
  return PublicSettingsLite.fromJson(await api.publicSettings());
});

/// 指定服务器的公开设置(登录/注册页:选服务器后取注册开关/条款等)。
final publicSettingsForServerProvider = FutureProvider.autoDispose
    .family<PublicSettingsLite, ServerProfile>((ref, server) async {
  final api = ref.watch(authApiForServerProvider(server));
  return PublicSettingsLite.fromJson(await api.publicSettings());
});
