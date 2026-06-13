import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../i18n/app_localizations.dart';
import '../../../../shared/format/formatters.dart';
import '../../../../shared/widgets/markdown_text.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../data/announcements_api.dart';
import '../providers/announcements_providers.dart';
import 'announcement_visuals.dart';

/// 公告沉浸详情页(替代旧的 AlertDialog)。进入时若未读则标记已读并刷新列表。
class AnnouncementDetailPage extends ConsumerStatefulWidget {
  const AnnouncementDetailPage({super.key, required this.announcement});

  final UserAnnouncement announcement;

  @override
  ConsumerState<AnnouncementDetailPage> createState() =>
      _AnnouncementDetailPageState();
}

class _AnnouncementDetailPageState
    extends ConsumerState<AnnouncementDetailPage> {
  @override
  void initState() {
    super.initState();
    if (!widget.announcement.isRead) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
    }
  }

  Future<void> _markRead() async {
    try {
      await ref.read(announcementsApiProvider).markRead(widget.announcement.id);
      ref.invalidate(announcementsListProvider);
      ref.invalidate(unreadAnnouncementsProvider);
    } catch (_) {
      // 标记已读失败不影响阅读
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.announcement;
    final scheme = Theme.of(context).colorScheme;
    final tone = announcementTone(a.notifyMode);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('announcements.detail'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusToneColor(tone).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(announcementIcon(a.notifyMode),
                    color: statusToneColor(tone), size: 22),
              ),
              const SizedBox(width: 12),
              StatusPill(
                label: context.tr(announcementModeLabelKey(a.notifyMode)),
                tone: tone,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            a.title,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (a.createdAt != null) ...[
            const SizedBox(height: 8),
            Text(
              formatDateTime(a.createdAt!),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          MarkdownText(a.content),
        ],
      ),
    );
  }
}

/// StatusTone → 取一个代表色(供图标底色用)。
Color statusToneColor(StatusTone tone) => switch (tone) {
      StatusTone.positive => AppColors.brandGreen,
      StatusTone.info => AppColors.brandBlue,
      StatusTone.warning => const Color(0xFFB7791F),
      StatusTone.danger => const Color(0xFFDC2626),
      StatusTone.neutral => const Color(0xFF94A3B8),
    };
