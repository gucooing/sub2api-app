import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';

/// 用户公告。
@immutable
class UserAnnouncement {
  const UserAnnouncement({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    required this.isRead,
    this.createdAt,
  });

  final int id;
  final String title;
  final String content;
  final String type;
  final bool isRead;
  final DateTime? createdAt;

  factory UserAnnouncement.fromJson(Map<String, dynamic> json) =>
      UserAnnouncement(
        id: (json['id'] as num).toInt(),
        title: json['title'] as String? ?? '',
        content: json['content'] as String? ?? '',
        type: json['type'] as String? ?? 'info',
        isRead: json['is_read'] as bool? ?? false,
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
