import 'package:flutter/foundation.dart';

/// 一个已登录的账号(账号 = 服务器 + 后端用户)。
///
/// 令牌按 [id] 分键存储于 SecureStore,故同一服务器的不同用户可并存。
@immutable
class AccountProfile {
  const AccountProfile({
    required this.id,
    required this.serverId,
    required this.userId,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    this.isAdmin = false,
  });

  /// 稳定标识:`<serverId>:<userId>`。同服务器同用户重登只更新,不重复。
  final String id;

  /// 关联的服务器(ServerStore 中的 ServerProfile.id)。
  final String serverId;

  /// 后端用户 id。
  final int userId;

  /// 邮箱(列表主标识)。
  final String email;

  /// 展示名(用户名或邮箱)。
  final String displayName;

  /// 头像(可为 base64 data URL)。
  final String? avatarUrl;

  /// 是否为管理员(登录/会话恢复时按后端用户角色写入,供账号列表展示标识)。
  final bool isAdmin;

  /// 由服务器与用户 id 派生账号 id。
  static String deriveId(String serverId, int userId) => '$serverId:$userId';

  AccountProfile copyWith({
    String? email,
    String? displayName,
    String? avatarUrl,
    bool? isAdmin,
  }) =>
      AccountProfile(
        id: id,
        serverId: serverId,
        userId: userId,
        email: email ?? this.email,
        displayName: displayName ?? this.displayName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        isAdmin: isAdmin ?? this.isAdmin,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'server_id': serverId,
        'user_id': userId,
        'email': email,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'is_admin': isAdmin,
      };

  factory AccountProfile.fromJson(Map<String, dynamic> json) => AccountProfile(
        id: json['id'] as String,
        serverId: json['server_id'] as String,
        userId: (json['user_id'] as num).toInt(),
        email: json['email'] as String? ?? '',
        displayName: json['display_name'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String?,
        isAdmin: json['is_admin'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      other is AccountProfile &&
      other.id == id &&
      other.serverId == serverId &&
      other.userId == userId &&
      other.email == email &&
      other.displayName == displayName &&
      other.avatarUrl == avatarUrl &&
      other.isAdmin == isAdmin;

  @override
  int get hashCode =>
      Object.hash(id, serverId, userId, email, displayName, avatarUrl, isAdmin);
}
