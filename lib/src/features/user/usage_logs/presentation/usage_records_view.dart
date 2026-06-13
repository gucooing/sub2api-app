import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../i18n/app_localizations.dart';
import '../../../../shared/format/formatters.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/model_icon.dart';
import '../../keys/providers/keys_providers.dart';
import '../data/usage_logs_api.dart';
import '../providers/usage_logs_providers.dart';
import 'records_filter_sheet.dart';

/// 使用记录列表视图(多维筛选 + 滚动加载 + 点击进详情)。
/// 既用于独立的「使用记录」页,也可嵌入用量页「明细」分段。
class UsageRecordsView extends ConsumerStatefulWidget {
  const UsageRecordsView({super.key});

  @override
  ConsumerState<UsageRecordsView> createState() => _UsageRecordsViewState();
}

class _UsageRecordsViewState extends ConsumerState<UsageRecordsView> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 400) {
      ref.read(usageRecordsProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(usageRecordsProvider);

    return Column(
      children: [
        _FilterBar(activeCount: state.filter.activeCount, total: state.total),
        Expanded(child: _buildBody(context, state)),
      ],
    );
  }

  Widget _buildBody(BuildContext context, UsageRecordsState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.items.isEmpty) {
      return ErrorRetryView(
        error: state.error!,
        onRetry: () => ref.read(usageRecordsProvider.notifier).refresh(),
      );
    }
    if (state.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => ref.read(usageRecordsProvider.notifier).refresh(),
        child: ListView(
          children: [
            const SizedBox(height: 80),
            EmptyState(
              icon: Icons.receipt_long_outlined,
              message: context.tr('usage.recordsEmpty'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(usageRecordsProvider.notifier).refresh(),
      child: ListView.separated(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: state.items.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          if (i == state.items.length) return _Footer(state: state);
          final log = state.items[i];
          return _RecordTile(log: log, groupName: _groupName(log));
        },
      ),
    );
  }

  /// 优先用日志内嵌分组名,否则按 group_id 在可用分组表里查。
  String? _groupName(UsageLog log) {
    if (log.groupName != null && log.groupName!.isNotEmpty) {
      return log.groupName;
    }
    if (log.groupId == null) return null;
    final groups = ref.watch(availableGroupsProvider).value ?? const [];
    for (final g in groups) {
      if (g.id == log.groupId) return g.name;
    }
    return null;
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.activeCount, required this.total});

  final int activeCount;
  final int total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Text(
            total > 0 ? '$total' : '',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const Spacer(),
          ActionChip(
            avatar: Badge(
              isLabelVisible: activeCount > 0,
              label: Text('$activeCount'),
              child: const Icon(Icons.filter_list, size: 18),
            ),
            label: Text(context.tr('usage.filter')),
            onPressed: () => showRecordsFilterSheet(context, ref),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.state});

  final UsageRecordsState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: state.isLoadingMore
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : !state.hasMore
                ? Text(
                    context.tr('usage.noMore'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  )
                : const SizedBox.shrink(),
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.log, this.groupName});

  final UsageLog log;
  final String? groupName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = log.status == 'success'
        ? scheme.primary
        : log.status == 'error'
            ? scheme.error
            : scheme.onSurfaceVariant;

    return Card(
      child: InkWell(
        onTap: () => context.push('/usage/logs/${log.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // 模型品牌图标 + 右下角状态点
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ModelIcon(model: log.model, size: 30),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Theme.of(context).cardColor, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      log.model,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    formatCost(log.actualCost ?? 0, decimals: 6),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  if (groupName != null)
                    _Meta(icon: Icons.layers_outlined, text: groupName!),
                  if (log.totalTokens != null)
                    _Meta(
                        icon: Icons.token_outlined,
                        text: formatCompact(log.totalTokens!)),
                  if (log.firstTokenMs != null)
                    _Meta(
                        icon: Icons.bolt_outlined,
                        text: '${context.tr('usage.firstToken')} '
                            '${log.firstTokenMs}ms'),
                  if (log.durationMs != null)
                    _Meta(
                        icon: Icons.timer_outlined,
                        text: '${log.durationMs}ms'),
                  if (log.createdAt != null)
                    _Meta(
                        icon: Icons.access_time,
                        text: formatDateTime(log.createdAt!)),
                  if (log.apiKeyName != null)
                    _Meta(icon: Icons.vpn_key_outlined, text: log.apiKeyName!),
                ],
              ),
            ],
          ),
        ),
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
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(text,
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(color: color)),
      ],
    );
  }
}
