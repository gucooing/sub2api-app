import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/account/account_store.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/server/server_store.dart';
import '../../../../core/session/session_controller.dart';
import '../../../../i18n/app_localizations.dart';
import '../../../../shared/format/formatters.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/brand_header.dart';
import '../../../../shared/widgets/responsive.dart';
import '../../../../shared/widgets/section_header.dart';
import '../data/affiliate_api.dart';
import '../providers/affiliate_providers.dart';

/// 邀请返利页:邀请码/链接(复制+二维码)、返利额度(可用/冻结/历史 + 转入余额)、被邀请人。
class AffiliatePage extends ConsumerWidget {
  const AffiliatePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(affiliateDetailProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('features.affiliate'))),
      body: ResponsiveCenter(
        child: AsyncValueView(
        value: detailAsync,
        onRetry: () => ref.invalidate(affiliateDetailProvider),
        builder: (context, detail) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(affiliateDetailProvider);
            await ref.read(affiliateDetailProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              _header(context, detail),
              const SizedBox(height: 12),
              _inviteCard(context, ref, detail),
              _quotaCard(context, ref, detail),
              _invitees(context, detail),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _header(BuildContext context, AffiliateDetail d) {
    return BrandHeader(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('affiliate.rebateRate'),
              style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 6),
          Text(
            '${d.rebateRatePercent.toStringAsFixed(d.rebateRatePercent % 1 == 0 ? 0 : 1)}%',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr('affiliate.inviteCount',
                params: {'count': d.affCount.toString()}),
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _inviteLink(WidgetRef ref, String code) {
    final account = ref.read(activeAccountProvider);
    final servers = ref.read(serverStoreProvider).servers;
    final origin = account == null
        ? ref.read(activeServerProvider).baseUrl
        : servers
            .firstWhere((s) => s.id == account.serverId,
                orElse: () => ref.read(activeServerProvider))
            .baseUrl;
    return '$origin/register?aff=${Uri.encodeComponent(code)}';
  }

  Widget _inviteCard(BuildContext context, WidgetRef ref, AffiliateDetail d) {
    final link = _inviteLink(ref, d.affCode);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _copyRow(
                context,
                label: context.tr('affiliate.inviteCode'),
                value: d.affCode,
                copyValue: d.affCode,
                mono: true,
              ),
              const SizedBox(height: 12),
              _copyRow(
                context,
                label: context.tr('affiliate.inviteLink'),
                value: link,
                copyValue: link,
              ),
              if (d.affCode.isNotEmpty) ...[
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: QrImageView(
                      data: link,
                      size: 168,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _copyRow(
    BuildContext context, {
    required String label,
    required String value,
    required String copyValue,
    bool mono = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                value.isEmpty ? '—' : value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: mono
                    ? Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)
                    : Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 18),
              visualDensity: VisualDensity.compact,
              onPressed: copyValue.isEmpty
                  ? null
                  : () async {
                      await Clipboard.setData(ClipboardData(text: copyValue));
                      if (context.mounted) {
                        showAppToast(context, context.tr('common.copied'));
                      }
                    },
            ),
          ],
        ),
      ],
    );
  }

  Widget _quotaCard(BuildContext context, WidgetRef ref, AffiliateDetail d) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _quotaStat(context, context.tr('affiliate.quotaAvailable'),
                      d.affQuota, primary: true),
                  _quotaStat(context, context.tr('affiliate.quotaFrozen'),
                      d.affFrozenQuota),
                  _quotaStat(context, context.tr('affiliate.quotaHistory'),
                      d.affHistoryQuota),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: d.affQuota > 0
                    ? () => _transfer(context, ref, d.affQuota)
                    : null,
                icon: const Icon(Icons.swap_horiz),
                label: Text(context.tr('affiliate.transfer')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quotaStat(BuildContext context, String label, double value,
      {bool primary = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Text(
            formatCost(value),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: primary ? scheme.primary : null,
                ),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _invitees(BuildContext context, AffiliateDetail d) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: context.tr('affiliate.invitees')),
          if (d.invitees.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    context.tr('affiliate.inviteesEmpty'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < d.invitees.length; i++) ...[
                    _inviteeTile(context, d.invitees[i]),
                    if (i != d.invitees.length - 1)
                      const Divider(height: 1, indent: 14, endIndent: 14),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _inviteeTile(BuildContext context, AffiliateInvitee inv) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      title: Text(inv.email.isNotEmpty ? inv.email : inv.username,
          overflow: TextOverflow.ellipsis),
      subtitle: inv.createdAt != null
          ? Text(formatDate(inv.createdAt!),
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant))
          : null,
      trailing: Text(
        '+${formatCost(inv.totalRebate)}',
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w600),
      ),
    );
  }

  Future<void> _transfer(
      BuildContext context, WidgetRef ref, double amount) async {
    try {
      final result = await ref.read(affiliateApiProvider).transfer();
      ref.invalidate(affiliateDetailProvider);
      await ref.read(sessionControllerProvider.notifier).refreshUser();
      if (!context.mounted) return;
      showAppToast(
        context,
        result.transferredQuota > 0
            ? context.tr('affiliate.transferred', params: {
                'amount': formatCost(result.transferredQuota)
              })
            : context.tr('affiliate.transferEmpty'),
      );
    } catch (e) {
      if (!context.mounted) return;
      showAppToast(
        context,
        e is ApiException
            ? (e.serverMessage ?? context.tr('common.unknownError'))
            : context.tr('common.unknownError'),
      );
    }
  }
}
