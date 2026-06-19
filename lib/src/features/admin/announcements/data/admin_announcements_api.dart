import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';

/// 公告定向条件:type=subscription(按订阅分组,operator 固定 in,group_ids)
/// 或 type=balance(按余额,operator gt/gte/lt/lte/eq + value)。
@immutable
class AnnouncementCondition {
  const AnnouncementCondition({
    required this.type,
    required this.operator,
    this.groupIds = const [],
    this.value,
  });

  final String type; // subscription / balance
  final String operator; // in / gt / gte / lt / lte / eq
  final List<int> groupIds;
  final num? value;

  AnnouncementCondition copyWith({
    String? type,
    String? operator,
    List<int>? groupIds,
    num? value,
  }) =>
      AnnouncementCondition(
        type: type ?? this.type,
        operator: operator ?? this.operator,
        groupIds: groupIds ?? this.groupIds,
        value: value ?? this.value,
      );

  factory AnnouncementCondition.fromJson(Map<String, dynamic> j) =>
      AnnouncementCondition(
        type: j['type'] as String? ?? 'subscription',
        operator: j['operator'] as String? ?? 'in',
        groupIds: [
          for (final e in (j['group_ids'] as List? ?? const []))
            if (e is num) e.toInt(),
        ],
        value: j['value'] as num?,
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'operator': operator,
        if (type == 'subscription') 'group_ids': groupIds,
        if (type == 'balance') 'value': value ?? 0,
      };
}

/// 一个「与」条件组(all_of:组内条件需全部满足)。
@immutable
class AnnouncementConditionGroup {
  const AnnouncementConditionGroup({this.allOf = const []});

  final List<AnnouncementCondition> allOf;

  factory AnnouncementConditionGroup.fromJson(Map<String, dynamic> j) =>
      AnnouncementConditionGroup(
        allOf: [
          for (final e in (j['all_of'] as List? ?? const []))
            if (e is Map) AnnouncementCondition.fromJson(e.cast<String, dynamic>()),
        ],
      );

  Map<String, dynamic> toJson() =>
      {'all_of': [for (final c in allOf) c.toJson()]};
}

/// 公告定向(any_of:满足任一条件组即命中;空 => 全部用户)。
@immutable
class AnnouncementTargeting {
  const AnnouncementTargeting({this.anyOf = const []});

  final List<AnnouncementConditionGroup> anyOf;

  bool get isAll => anyOf.isEmpty;

  factory AnnouncementTargeting.fromJson(Map<String, dynamic>? j) =>
      AnnouncementTargeting(
        anyOf: [
          for (final e in (j?['any_of'] as List? ?? const []))
            if (e is Map)
              AnnouncementConditionGroup.fromJson(e.cast<String, dynamic>()),
        ],
      );

  Map<String, dynamic> toJson() =>
      {'any_of': [for (final g in anyOf) g.toJson()]};
}

@immutable
class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.status,
    required this.notifyMode,
    required this.targeting,
    this.startsAt,
    this.endsAt,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String title;
  final String content;
  final String status; // draft / active / archived
  final String notifyMode; // silent / popup
  final AnnouncementTargeting targeting;
  final String? startsAt;
  final String? endsAt;
  final String? createdAt;
  final String? updatedAt;

  factory Announcement.fromJson(Map<String, dynamic> j) => Announcement(
        id: (j['id'] as num?)?.toInt() ?? 0,
        title: j['title'] as String? ?? '',
        content: j['content'] as String? ?? '',
        status: j['status'] as String? ?? 'draft',
        notifyMode: j['notify_mode'] as String? ?? 'silent',
        targeting: AnnouncementTargeting.fromJson(
            (j['targeting'] as Map?)?.cast<String, dynamic>()),
        startsAt: j['starts_at'] as String?,
        endsAt: j['ends_at'] as String?,
        createdAt: j['created_at'] as String?,
        updatedAt: j['updated_at'] as String?,
      );
}

@immutable
class AnnouncementPage {
  const AnnouncementPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pages,
  });

  final List<Announcement> items;
  final int total;
  final int page;
  final int pages;

  factory AnnouncementPage.fromJson(Map<String, dynamic> json) {
    final list = json['items'] as List? ?? const [];
    return AnnouncementPage(
      items: list
          .whereType<Map>()
          .map((e) => Announcement.fromJson(e.cast<String, dynamic>()))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pages: (json['pages'] as num?)?.toInt() ?? 1,
    );
  }
}

/// 某公告对某用户的可见性 + 已读状态。
@immutable
class AnnouncementReadStatus {
  const AnnouncementReadStatus({
    required this.userId,
    required this.email,
    required this.username,
    required this.balance,
    required this.eligible,
    this.readAt,
  });

  final int userId;
  final String email;
  final String username;
  final num balance;
  final bool eligible;
  final String? readAt;

  factory AnnouncementReadStatus.fromJson(Map<String, dynamic> j) =>
      AnnouncementReadStatus(
        userId: (j['user_id'] as num?)?.toInt() ?? 0,
        email: j['email'] as String? ?? '',
        username: j['username'] as String? ?? '',
        balance: j['balance'] as num? ?? 0,
        eligible: j['eligible'] as bool? ?? false,
        readAt: j['read_at'] as String?,
      );
}

@immutable
class AnnouncementReadStatusPage {
  const AnnouncementReadStatusPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pages,
  });

  final List<AnnouncementReadStatus> items;
  final int total;
  final int page;
  final int pages;

  factory AnnouncementReadStatusPage.fromJson(Map<String, dynamic> json) {
    final list = json['items'] as List? ?? const [];
    return AnnouncementReadStatusPage(
      items: list
          .whereType<Map>()
          .map((e) => AnnouncementReadStatus.fromJson(e.cast<String, dynamic>()))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pages: (json['pages'] as num?)?.toInt() ?? 1,
    );
  }
}

/// 管理端公告 API(对照 web api/admin/announcements.ts)。
class AdminAnnouncementsApi {
  AdminAnnouncementsApi(this._client);

  final ApiClient _client;

  Future<AnnouncementPage> list({
    int page = 1,
    int pageSize = 20,
    String? status,
    String? search,
    String sortBy = 'created_at',
    String sortOrder = 'desc',
  }) async {
    final data = await _client.get<dynamic>('/admin/announcements', query: {
      'page': page,
      'page_size': pageSize,
      if (status != null && status.isNotEmpty) 'status': status,
      if (search != null && search.isNotEmpty) 'search': search,
      'sort_by': sortBy,
      'sort_order': sortOrder,
    });
    return AnnouncementPage.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<Announcement> getById(int id) async {
    final data = await _client.get<dynamic>('/admin/announcements/$id');
    return Announcement.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<Announcement> create(Map<String, dynamic> body) async {
    final data = await _client.post<dynamic>('/admin/announcements', data: body);
    return Announcement.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<Announcement> update(int id, Map<String, dynamic> body) async {
    final data =
        await _client.put<dynamic>('/admin/announcements/$id', data: body);
    return Announcement.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<void> delete(int id) =>
      _client.delete<dynamic>('/admin/announcements/$id');

  Future<AnnouncementReadStatusPage> readStatus(
    int id, {
    int page = 1,
    int pageSize = 20,
    String? search,
    String sortBy = 'email',
    String sortOrder = 'asc',
  }) async {
    final data =
        await _client.get<dynamic>('/admin/announcements/$id/read-status', query: {
      'page': page,
      'page_size': pageSize,
      if (search != null && search.isNotEmpty) 'search': search,
      'sort_by': sortBy,
      'sort_order': sortOrder,
    });
    return AnnouncementReadStatusPage.fromJson(
        (data as Map).cast<String, dynamic>());
  }
}
