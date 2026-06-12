import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../i18n/app_localizations.dart';
import '../data/usage_logs_api.dart';
import '../providers/usage_logs_providers.dart';

/// 使用记录页面。
class UsageLogsPage extends ConsumerStatefulWidget {
  const UsageLogsPage({super.key});

  @override
  ConsumerState<UsageLogsPage> createState() => _UsageLogsPageState();
}

class _UsageLogsPageState extends ConsumerState<UsageLogsPage> {
  int _currentPage = 1;
  final int _pageSize = 20;

  @override
  Widget build(BuildContext context) {
    final params = UsageLogsParams(
      page: _currentPage,
      pageSize: _pageSize,
    );
    final logsAsync = ref.watch(usageLogsProvider(params));

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('usageLogs.title'))),
      body: logsAsync.when(
        data: (paginatedLogs) {
          if (paginatedLogs.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.list_alt_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('usageLogs.empty'),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: paginatedLogs.items.length,
                  itemBuilder: (context, index) {
                    final log = paginatedLogs.items[index];
                    return _UsageLogTile(log: log);
                  },
                ),
              ),
              if (paginatedLogs.totalPages > 1)
                _PaginationBar(
                  currentPage: _currentPage,
                  totalPages: paginatedLogs.totalPages,
                  onPageChanged: (page) {
                    setState(() => _currentPage = page);
                  },
                ),
            ],
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
                onPressed: () {
                  ref.invalidate(usageLogsProvider(UsageLogsParams(
                    page: _currentPage,
                    pageSize: _pageSize,
                  )));
                },
                icon: const Icon(Icons.refresh),
                label: Text(context.tr('common.retry')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 使用记录条目。
class _UsageLogTile extends StatelessWidget {
  const _UsageLogTile({required this.log});

  final UsageLog log;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatusIcon(status: log.status),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.model,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        log.provider,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${(log.actualCost ?? 0).toStringAsFixed(6)}',
                      style:
                          Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                    ),
                    if (log.durationMs != null)
                      Text(
                        '${log.durationMs}ms',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (log.inputTokens != null) ...[
                  Icon(Icons.input,
                      size: 14, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    '${log.inputTokens}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 12),
                ],
                if (log.outputTokens != null) ...[
                  Icon(Icons.output,
                      size: 14,
                      color: Theme.of(context).colorScheme.secondary),
                  const SizedBox(width: 4),
                  Text(
                    '${log.outputTokens}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 12),
                ],
                if (log.totalTokens != null) ...[
                  Icon(Icons.token,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    '${log.totalTokens}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
            if (log.createdAt != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.access_time,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    _formatDateTime(log.createdAt!),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  if (log.apiKeyName != null) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.vpn_key,
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        log.apiKeyName!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
            if ((log.cacheReadTokens != null && log.cacheReadTokens! > 0) ||
                (log.cacheCreationTokens != null &&
                    log.cacheCreationTokens! > 0)) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.cached,
                      size: 14,
                      color: Theme.of(context).colorScheme.tertiary),
                  const SizedBox(width: 4),
                  if (log.cacheReadTokens != null && log.cacheReadTokens! > 0)
                    Text(
                      '${context.tr('usageLogs.read')}: ${log.cacheReadTokens}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (log.cacheCreationTokens != null &&
                      log.cacheCreationTokens! > 0) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${context.tr('usageLogs.creation')}: ${log.cacheCreationTokens}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
}

/// 状态图标。
class _StatusIcon extends StatelessWidget {
  const _StatusIcon({this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = status == 'success'
        ? scheme.primary
        : status == 'error'
            ? scheme.error
            : scheme.onSurfaceVariant;

    return CircleAvatar(
      radius: 18,
      backgroundColor: color.withValues(alpha: 0.12),
      child: Icon(
        status == 'success'
            ? Icons.check
            : status == 'error'
                ? Icons.error_outline
                : Icons.remove,
        size: 18,
        color: color,
      ),
    );
  }
}

/// 分页栏。
class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: currentPage > 1
                ? () => onPageChanged(currentPage - 1)
                : null,
          ),
          Text(
            '$currentPage / $totalPages',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: currentPage < totalPages
                ? () => onPageChanged(currentPage + 1)
                : null,
          ),
        ],
      ),
    );
  }
}
