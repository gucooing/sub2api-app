import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../i18n/app_localizations.dart';
import '../data/announcements_api.dart';
import '../providers/announcements_providers.dart';

/// 公告列表页面。
class AnnouncementsPage extends ConsumerWidget {
  const AnnouncementsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcementsAsync = ref.watch(announcementsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('announcements.title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(announcementsListProvider),
          ),
        ],
      ),
      body: announcementsAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('announcements.empty'),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) => _AnnouncementTile(
              announcement: items[index],
              onTap: () => _showDetail(context, ref, items[index]),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(
                error is ApiException
                    ? error.serverMessage ?? context.tr('common.unknownError')
                    : context.tr('common.unknownError'),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => ref.invalidate(announcementsListProvider),
                icon: const Icon(Icons.refresh),
                label: Text(context.tr('common.retry')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(
      BuildContext context, WidgetRef ref, UserAnnouncement announcement) {
    showDialog(
      context: context,
      builder: (context) => _AnnouncementDetailDialog(
        announcement: announcement,
        onClose: () {
          // 标记为已读
          if (!announcement.isRead) {
            ref
                .read(announcementsApiProvider)
                .markRead(announcement.id)
                .then((_) => ref.invalidate(announcementsListProvider));
          }
        },
      ),
    );
  }
}

/// 公告列表项。
class _AnnouncementTile extends StatelessWidget {
  const _AnnouncementTile({
    required this.announcement,
    required this.onTap,
  });

  final UserAnnouncement announcement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: announcement.isRead
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Theme.of(context).colorScheme.primaryContainer,
        child: Icon(
          _getIcon(),
          color: announcement.isRead
              ? Theme.of(context).colorScheme.onSurfaceVariant
              : Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
      title: Row(
        children: [
          Expanded(child: Text(announcement.title)),
          if (!announcement.isRead)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
      subtitle: announcement.createdAt != null
          ? Text(_formatDateTime(announcement.createdAt!))
          : null,
      onTap: onTap,
    );
  }

  IconData _getIcon() {
    switch (announcement.type) {
      case 'warning':
        return Icons.warning;
      case 'error':
        return Icons.error;
      case 'success':
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

/// 公告详情对话框。
class _AnnouncementDetailDialog extends StatelessWidget {
  const _AnnouncementDetailDialog({
    required this.announcement,
    required this.onClose,
  });

  final UserAnnouncement announcement;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(announcement.title),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (announcement.createdAt != null) ...[
              Text(
                _formatDateTime(announcement.createdAt!),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
            ],
            Text(announcement.content),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onClose();
          },
          child: Text(context.tr('common.close')),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
