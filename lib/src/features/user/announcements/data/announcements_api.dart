import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';

/// 用户公告。
@immutable
class UserAnnouncement {
  const UserAnnouncement({
    required this.id,
    required this.title,
    required this.content,
    required this.notifyMode,
    required this.isRead,
    this.createdAt,
  });

  final int id;
  final String title;
  final String content;

  /// 'silent' | 'popup'(popup 进入总览时自动弹窗)。
  final String notifyMode;
  final bool isRead;
  final DateTime? createdAt;

  /// 是否为弹窗公告。
  bool get isPopup => notifyMode == 'popup';

  factory UserAnnouncement.fromJson(Map<String, dynamic> json) =>
      UserAnnouncement(
        id: (json['id'] as num).toInt(),
        title: json['title'] as String? ?? '',
        content: json['content'] as String? ?? '',
        notifyMode: json['notify_mode'] as String? ?? 'silent',
        // 后端用 read_at(已读时间)表示已读;兼容旧 is_read 字段。
        isRead: json['read_at'] != null || json['is_read'] == true,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)?.toLocal()
            : null,
      );
}

/// 公告 API。
class AnnouncementsApi {
  AnnouncementsApi(this._client);

  final ApiClient _client;

  /// 获取公告列表。
  Future<List<UserAnnouncement>> list({bool unreadOnly = false}) async {
    final data = await _client.get<dynamic>(
      '/announcements',
      query: unreadOnly ? {'unread_only': 1} : null,
    );
    final list = data as List? ?? const [];
    return list
        .whereType<Map>()
        .map((e) => UserAnnouncement.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// 标记公告为已读。
  Future<void> markRead(int id) async {
    await _client.post<dynamic>('/announcements/$id/read');
  }
}
