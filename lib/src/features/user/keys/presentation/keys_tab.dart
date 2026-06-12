import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../i18n/app_localizations.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../data/keys_api.dart';
import '../providers/keys_providers.dart';
import 'key_edit_sheet.dart';

/// 「密钥」tab:API 密钥列表与管理(创建/编辑/启停/删除/复制)。
class KeysTab extends ConsumerWidget {
  const KeysTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keys = ref.watch(keysListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('nav.keys'))),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'keys-fab',
        onPressed: () => showKeyEditSheet(context, ref),
        icon: const Icon(Icons.add),
        label: Text(context.tr('keys.create')),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(keysListProvider);
          try {
            await ref.read(keysListProvider.future);
          } on Exception {
            // 错误展示交给 AsyncValueView
          }
        },
        child: AsyncValueView(
          value: keys,
          onRetry: () => ref.invalidate(keysListProvider),
          builder: (context, list) {
            if (list.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  Icon(
                    Icons.vpn_key_off_outlined,
                    size: 56,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 12),
                  Center(child: Text(context.tr('keys.emptyHint'))),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _KeyCard(info: list[i]),
            );
          },
        ),
      ),
    );
  }
}

class _KeyCard extends ConsumerWidget {
  const _KeyCard({required this.info});

  final ApiKeyInfo info;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    info.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _StatusChip(status: info.status),
                _ActionsMenu(info: info),
              ],
            ),
            const SizedBox(height: 8),
            // 密钥脱敏 + 复制
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: info.key));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.tr('common.copied'))),
                  );
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        info.maskedKey,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontFamily: 'monospace'),
                      ),
                    ),
                    Icon(Icons.copy, size: 16, color: scheme.primary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                if (info.groupName != null)
                  _Meta(icon: Icons.folder_outlined, text: info.groupName!),
                _Meta(
                  icon: Icons.data_usage_outlined,
                  text: info.quota > 0
                      ? '\$${info.quotaUsed.toStringAsFixed(2)} / \$${info.quota.toStringAsFixed(2)}'
                      : '\$${info.quotaUsed.toStringAsFixed(2)} / ${context.tr('keys.unlimited')}',
                ),
                if (info.expiresAt != null)
                  _Meta(
                    icon: Icons.schedule_outlined,
                    text:
                        '${context.tr('keys.expires')} ${_date(info.expiresAt!)}',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _ActionsMenu extends ConsumerWidget {
  const _ActionsMenu({required this.info});

  final ApiKeyInfo info;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MenuAnchor(
      builder: (context, controller, _) => IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.edit_outlined),
          onPressed: () => showKeyEditSheet(context, ref, existing: info),
          child: Text(context.tr('common.edit')),
        ),
        MenuItemButton(
          leadingIcon: Icon(
            info.isActive
                ? Icons.pause_circle_outline
                : Icons.play_circle_outline,
          ),
          onPressed: () => _toggle(context, ref),
          child: Text(
            info.isActive
                ? context.tr('keys.disable')
                : context.tr('keys.enable'),
          ),
        ),
        MenuItemButton(
          leadingIcon: Icon(
            Icons.delete_outline,
            color: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => _confirmDelete(context, ref),
          child: Text(
            context.tr('common.delete'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ],
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(keysApiProvider).update(
            info.id,
            status: info.isActive ? 'inactive' : 'active',
          );
      ref.invalidate(keysListProvider);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.localizedMessage(context))),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('common.delete')),
        content:
            Text(context.tr('keys.deleteConfirm', params: {'name': info.name})),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('common.cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('common.delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(keysApiProvider).remove(info.id);
      ref.invalidate(keysListProvider);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.localizedMessage(context))),
        );
      }
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, bg, fg) = switch (status) {
      'active' => (
          context.tr('keys.statusActive'),
          scheme.primaryContainer,
          scheme.onPrimaryContainer
        ),
      'inactive' => (
          context.tr('keys.statusInactive'),
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant
        ),
      'quota_exhausted' => (
          context.tr('keys.statusQuotaExhausted'),
          scheme.errorContainer,
          scheme.onErrorContainer
        ),
      'expired' => (
          context.tr('keys.statusExpired'),
          scheme.errorContainer,
          scheme.onErrorContainer
        ),
      _ => (status, scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
