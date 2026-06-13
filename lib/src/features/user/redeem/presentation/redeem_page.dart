import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/session/session_controller.dart';
import '../../../../i18n/app_localizations.dart';
import '../../../../shared/widgets/responsive.dart';
import '../data/redeem_api.dart';
import '../providers/redeem_providers.dart';

/// 兑换码兑换页面。
class RedeemPage extends ConsumerStatefulWidget {
  const RedeemPage({super.key});

  @override
  ConsumerState<RedeemPage> createState() => _RedeemPageState();
}

class _RedeemPageState extends ConsumerState<RedeemPage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final api = ref.read(redeemApiProvider);
      final result = await api.redeem(_codeController.text.trim());

      if (!mounted) return;

      // 刷新用户信息(余额可能变化)
      ref.read(sessionControllerProvider.notifier).refreshUser();
      // 刷新兑换历史
      ref.invalidate(redeemHistoryProvider);

      _codeController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    } catch (error) {
      if (!mounted) return;

      final message = error is ApiException
          ? error.serverMessage ?? context.tr('common.unknownError')
          : context.tr('common.unknownError');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(redeemHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('redeem.title'))),
      body: ResponsiveCenter(
        maxWidth: 640,
        child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _codeController,
                        decoration: InputDecoration(
                          labelText: context.tr('redeem.code'),
                          hintText: context.tr('redeem.codeHint'),
                          prefixIcon: const Icon(Icons.card_giftcard),
                          border: const OutlineInputBorder(),
                        ),
                        enabled: !_isLoading,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return context.tr('redeem.codeRequired');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _isLoading ? null : _redeem,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(context.tr('redeem.submit')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  context.tr('redeem.history'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => ref.invalidate(redeemHistoryProvider),
                  icon: const Icon(Icons.refresh, size: 20),
                  label: Text(context.tr('common.refresh')),
                ),
              ],
            ),
          ),
          Expanded(
            child: historyAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      context.tr('redeem.historyEmpty'),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) =>
                      _HistoryTile(item: items[index]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text(
                  error is ApiException
                      ? error.serverMessage ?? context.tr('common.unknownError')
                      : context.tr('common.unknownError'),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

/// 兑换历史条目。
class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item});

  final RedeemHistoryItem item;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        child: Icon(_getIcon()),
      ),
      title: Text(item.code),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_getTypeLabel(context)),
          if (item.usedAt != null)
            Text(
              _formatDateTime(item.usedAt!),
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
      trailing: Text(
        _getValueText(),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }

  IconData _getIcon() {
    switch (item.type) {
      case 'balance':
      case 'admin_balance':
        return Icons.account_balance_wallet;
      case 'subscription':
        return Icons.card_membership;
      case 'concurrency':
      case 'admin_concurrency':
        return Icons.speed;
      default:
        return Icons.redeem;
    }
  }

  String _getTypeLabel(BuildContext context) {
    switch (item.type) {
      case 'balance':
      case 'admin_balance':
        return context.tr('redeem.typeBalance');
      case 'subscription':
        return item.groupName != null
            ? context.tr('redeem.typeSubscription',
                params: {'group': item.groupName!})
            : context.tr('redeem.typeSubscription', params: {'group': ''});
      case 'concurrency':
      case 'admin_concurrency':
        return context.tr('redeem.typeConcurrency');
      default:
        return item.type;
    }
  }

  String _getValueText() {
    switch (item.type) {
      case 'balance':
      case 'admin_balance':
        return '+\$${item.value.toStringAsFixed(2)}';
      case 'subscription':
        return item.validityDays != null ? '${item.validityDays}d' : '';
      case 'concurrency':
      case 'admin_concurrency':
        return '+${item.value.toInt()}';
      default:
        return item.value.toString();
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

