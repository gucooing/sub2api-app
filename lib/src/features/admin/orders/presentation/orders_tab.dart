import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../i18n/app_localizations.dart';
import '../../../../shared/format/formatters.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/responsive.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../data/admin_payment_api.dart';
import '../providers/admin_payment_providers.dart';

/// 订单状态 → 配色语气(对照 web OrderStatusBadge)。
StatusTone orderStatusTone(String status) => switch (status) {
      'COMPLETED' => StatusTone.positive,
      'PAID' || 'RECHARGING' || 'REFUNDED' => StatusTone.info,
      'PENDING' ||
      'REFUND_REQUESTED' ||
      'REFUNDING' ||
      'PARTIALLY_REFUNDED' =>
        StatusTone.warning,
      'FAILED' || 'REFUND_FAILED' => StatusTone.danger,
      _ => StatusTone.neutral,
    };

String orderStatusLabel(BuildContext context, String status) {
  final key = 'adminOrders.status.$status';
  final v = context.tr(key);
  return v == key ? status : v;
}

String paymentMethodLabel(BuildContext context, String type) {
  if (type.isEmpty) return '-';
  final key = 'adminOrders.method.$type';
  final v = context.tr(key);
  return v == key ? type : v;
}

/// 订单管理 Tab:列表 + 搜索 + 筛选弹层 + 详情弹层 + 取消/重试/退款。
class OrdersTab extends ConsumerStatefulWidget {
  const OrdersTab({super.key});

  @override
  ConsumerState<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends ConsumerState<OrdersTab>
    with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
        ref.read(adminOrdersControllerProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = ref.watch(adminOrdersControllerProvider);
    final ctrl = ref.read(adminOrdersControllerProvider.notifier);
    final hasFilters = state.status.isNotEmpty ||
        state.paymentType.isNotEmpty ||
        state.orderType.isNotEmpty;
    return Column(
      children: [
        ResponsiveCenter(
          maxWidth: 1100,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onSubmitted: ctrl.setSearch,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: context.tr('adminOrders.searchHint'),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Badge(
                  isLabelVisible: hasFilters,
                  child: IconButton.filledTonal(
                    onPressed: () => _showFilters(context, state, ctrl),
                    icon: const Icon(Icons.tune),
                    tooltip: context.tr('adminOrders.filters'),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(child: _body(context, state, ctrl)),
      ],
    );
  }

  Widget _body(
      BuildContext context, AdminOrdersState state, AdminOrdersController ctrl) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.items.isEmpty) {
      return ErrorRetryView(error: state.error!, onRetry: ctrl.refresh);
    }
    if (state.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: ctrl.refresh,
        child: ListView(children: [
          const SizedBox(height: 120),
          EmptyState(
              icon: Icons.receipt_long_outlined,
              message: context.tr('adminOrders.empty')),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: ctrl.refresh,
      child: ResponsiveCenter(
        maxWidth: 1100,
        child: ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 24),
          itemCount: state.items.length + 1,
          itemBuilder: (context, i) {
            if (i == state.items.length) {
              if (state.loadingMore) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: Text(
                    context.tr('adminOrders.totalOrders',
                        params: {'n': '${state.total}'}),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              );
            }
            return _OrderCard(
              order: state.items[i],
              onTap: () => _showDetail(context, state.items[i]),
              onAction: (a) => _runAction(context, ctrl, state.items[i], a),
            );
          },
        ),
      ),
    );
  }

  Future<void> _runAction(BuildContext context, AdminOrdersController ctrl,
      PaymentOrder o, _OrderAction a) async {
    final api = ref.read(adminPaymentApiProvider);
    switch (a) {
      case _OrderAction.view:
        _showDetail(context, o);
      case _OrderAction.cancel:
        final ok = await showConfirmDialog(
          context,
          title: context.tr('adminOrders.cancelOrder'),
          message: context.tr('adminOrders.cancelConfirm'),
          confirmLabel: context.tr('adminOrders.cancelOrder'),
          destructive: true,
        );
        if (!ok) return;
        try {
          await api.cancelOrder(o.id);
          await ctrl.refresh();
          if (context.mounted) {
            showAppToast(context, context.tr('adminOrders.orderCancelled'));
          }
        } catch (e) {
          if (context.mounted) showAppToast(context, '$e', error: true);
        }
      case _OrderAction.retry:
        try {
          await api.retryRecharge(o.id);
          await ctrl.refresh();
          if (context.mounted) {
            showAppToast(context, context.tr('adminOrders.retrySuccess'));
          }
        } catch (e) {
          if (context.mounted) showAppToast(context, '$e', error: true);
        }
      case _OrderAction.refund:
        final params = await showModalBottomSheet<_RefundResult>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => _RefundSheet(order: o),
        );
        if (params == null) return;
        try {
          await api.refundOrder(o.id,
              amount: params.amount,
              reason: params.reason,
              deductBalance: params.deductBalance,
              force: params.force);
          await ctrl.refresh();
          if (context.mounted) {
            showAppToast(context, context.tr('adminOrders.refundSuccess'));
          }
        } catch (e) {
          if (context.mounted) showAppToast(context, '$e', error: true);
        }
    }
  }

  void _showFilters(
      BuildContext context, AdminOrdersState state, AdminOrdersController ctrl) {
    var status = state.status;
    var paymentType = state.paymentType;
    var orderType = state.orderType;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ctx.tr('adminOrders.filters'),
                    style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 12),
                _filterGroup(
                  ctx,
                  label: ctx.tr('adminOrders.statusLabel'),
                  options: _statusOptions,
                  selected: status,
                  labelOf: (v) => v.isEmpty
                      ? ctx.tr('adminOrders.allStatus')
                      : orderStatusLabel(ctx, v),
                  onSelected: (v) => setS(() => status = v),
                ),
                const SizedBox(height: 12),
                _filterGroup(
                  ctx,
                  label: ctx.tr('adminOrders.paymentMethod'),
                  options: _paymentTypeOptions,
                  selected: paymentType,
                  labelOf: (v) => v.isEmpty
                      ? ctx.tr('adminOrders.allPaymentTypes')
                      : paymentMethodLabel(ctx, v),
                  onSelected: (v) => setS(() => paymentType = v),
                ),
                const SizedBox(height: 12),
                _filterGroup(
                  ctx,
                  label: ctx.tr('adminOrders.orderType'),
                  options: const ['', 'balance', 'subscription'],
                  selected: orderType,
                  labelOf: (v) => switch (v) {
                    'balance' => ctx.tr('adminOrders.balanceOrder'),
                    'subscription' => ctx.tr('adminOrders.subscriptionOrder'),
                    _ => ctx.tr('adminOrders.allOrderTypes'),
                  },
                  onSelected: (v) => setS(() => orderType = v),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setS(() {
                          status = '';
                          paymentType = '';
                          orderType = '';
                        }),
                        child: Text(ctx.tr('adminOrders.reset')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          ctrl.applyFilters(
                              status: status,
                              paymentType: paymentType,
                              orderType: orderType);
                          Navigator.pop(ctx);
                        },
                        child: Text(ctx.tr('adminOrders.apply')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterGroup(
    BuildContext context, {
    required String label,
    required List<String> options,
    required String selected,
    required String Function(String) labelOf,
    required ValueChanged<String> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final o in options)
              ChoiceChip(
                label: Text(labelOf(o)),
                selected: selected == o,
                onSelected: (_) => onSelected(o),
              ),
          ],
        ),
      ],
    );
  }

  void _showDetail(BuildContext context, PaymentOrder order) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _OrderDetailSheet(orderId: order.id, cached: order),
    );
  }
}

const _statusOptions = [
  '',
  'PENDING',
  'PAID',
  'COMPLETED',
  'EXPIRED',
  'CANCELLED',
  'FAILED',
  'REFUNDED',
  'REFUND_REQUESTED',
  'REFUND_FAILED',
];

const _paymentTypeOptions = ['', 'alipay', 'wxpay', 'stripe', 'airwallex'];

enum _OrderAction { view, cancel, retry, refund }

class _OrderCard extends StatelessWidget {
  const _OrderCard(
      {required this.order, required this.onTap, required this.onAction});

  final PaymentOrder order;
  final VoidCallback onTap;
  final ValueChanged<_OrderAction> onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: scheme.onSurfaceVariant);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('#${order.id}',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(order.outTradeNo,
                      style: muted, overflow: TextOverflow.ellipsis),
                ),
                StatusPill(
                    label: orderStatusLabel(context, order.status),
                    tone: orderStatusTone(order.status),
                    dense: true),
                PopupMenuButton<_OrderAction>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  padding: EdgeInsets.zero,
                  onSelected: onAction,
                  itemBuilder: (context) => [
                    PopupMenuItem(
                        value: _OrderAction.view,
                        height: 40,
                        child: Text(context.tr('adminOrders.viewDetail'))),
                    if (order.status == 'PENDING')
                      PopupMenuItem(
                          value: _OrderAction.cancel,
                          height: 40,
                          child: Text(context.tr('adminOrders.cancelOrder'))),
                    if (order.status == 'FAILED')
                      PopupMenuItem(
                          value: _OrderAction.retry,
                          height: 40,
                          child: Text(context.tr('adminOrders.retry'))),
                    if (_canRefund(order.status))
                      PopupMenuItem(
                          value: _OrderAction.refund,
                          height: 40,
                          child: Text(_refundLabel(context, order.status),
                              style: TextStyle(color: scheme.tertiary))),
                  ],
                ),
              ]),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Wrap(spacing: 8, runSpacing: 2, children: [
                  Text('¥${order.payAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                          color: scheme.primary, fontWeight: FontWeight.w600)),
                  if (order.amount != order.payAmount)
                    Text(
                        '${context.tr('adminOrders.credited')} ${order.amountSymbol}${order.amount.toStringAsFixed(2)}',
                        style: muted),
                  Text('·', style: muted),
                  Text(paymentMethodLabel(context, order.paymentType),
                      style: muted),
                  Text('·', style: muted),
                  Text(order.orderType == 'balance'
                      ? context.tr('adminOrders.balanceOrder')
                      : context.tr('adminOrders.subscriptionOrder'),
                      style: muted),
                  Text('·', style: muted),
                  Text('U#${order.userId}', style: muted),
                  if (order.createdAt != null) ...[
                    Text('·', style: muted),
                    Text(_fmt(order.createdAt), style: muted),
                  ],
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static bool _canRefund(String status) => const [
        'COMPLETED',
        'PARTIALLY_REFUNDED',
        'REFUND_REQUESTED',
        'REFUND_FAILED',
      ].contains(status);

  static String _refundLabel(BuildContext context, String status) =>
      switch (status) {
        'REFUND_REQUESTED' => context.tr('adminOrders.approveRefund'),
        'REFUND_FAILED' => context.tr('adminOrders.retryRefund'),
        _ => context.tr('adminOrders.refund'),
      };

  static String _fmt(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final d = DateTime.tryParse(raw);
    return d == null ? raw : formatDateTime(d.toLocal());
  }
}

// ==================== 详情弹层 ====================

class _OrderDetailSheet extends ConsumerStatefulWidget {
  const _OrderDetailSheet({required this.orderId, required this.cached});

  final int orderId;
  final PaymentOrder cached;

  @override
  ConsumerState<_OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends ConsumerState<_OrderDetailSheet> {
  late PaymentOrder _order = widget.cached;
  List<OrderAuditLog> _logs = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await ref.read(adminPaymentApiProvider).getOrder(widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = d.order;
        _logs = d.auditLogs;
      });
    } catch (_) {
      /* 保留缓存订单 */
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = _order;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Row(
            children: [
              Text('${context.tr('adminOrders.orderDetail')} #${o.id}',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              StatusPill(
                  label: orderStatusLabel(context, o.status),
                  tone: orderStatusTone(o.status)),
            ],
          ),
          const SizedBox(height: 12),
          _kv(context, 'adminOrders.orderNo', o.outTradeNo),
          _kv(context, 'adminOrders.amount',
              '${o.amountSymbol}${o.amount.toStringAsFixed(2)}'),
          _kv(context, 'adminOrders.payAmount',
              '¥${o.payAmount.toStringAsFixed(2)}'),
          _kv(context, 'adminOrders.paymentMethod',
              paymentMethodLabel(context, o.paymentType)),
          _kv(context, 'adminOrders.orderType',
              o.orderType == 'balance'
                  ? context.tr('adminOrders.balanceOrder')
                  : context.tr('adminOrders.subscriptionOrder')),
          _kv(context, 'adminOrders.feeRate', '${o.feeRate}%'),
          _kv(context, 'adminOrders.userId', '#${o.userId}'),
          if (o.createdAt != null)
            _kv(context, 'adminOrders.createdAt', _fmt(o.createdAt)),
          if (o.expiresAt != null)
            _kv(context, 'adminOrders.expiresAt', _fmt(o.expiresAt)),
          if (o.paidAt != null)
            _kv(context, 'adminOrders.paidAt', _fmt(o.paidAt)),
          if (o.completedAt != null)
            _kv(context, 'adminOrders.completedAt', _fmt(o.completedAt)),
          if (o.refundAmount > 0)
            _kv(context, 'adminOrders.refundAmount',
                '${o.amountSymbol}${o.refundAmount.toStringAsFixed(2)}',
                valueColor: Theme.of(context).colorScheme.error),
          if (o.refundReason != null && o.refundReason!.isNotEmpty)
            _kv(context, 'adminOrders.refundReason', o.refundReason!),
          if (o.refundRequestedAt != null) ...[
            const Divider(height: 24),
            Text(context.tr('adminOrders.refundRequestInfo'),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.tertiary)),
            const SizedBox(height: 6),
            _kv(context, 'adminOrders.refundRequestedAt',
                _fmt(o.refundRequestedAt)),
            if (o.refundRequestedBy != null)
              _kv(context, 'adminOrders.refundRequestedBy',
                  '#${o.refundRequestedBy}'),
            if (o.refundRequestReason != null &&
                o.refundRequestReason!.isNotEmpty)
              _kv(context, 'adminOrders.refundRequestReason',
                  o.refundRequestReason!),
          ],
          if (_logs.isNotEmpty) ...[
            const Divider(height: 24),
            Text(context.tr('adminOrders.auditLogs'),
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            for (final log in _logs) _logTile(context, log),
          ],
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String labelKey, String value,
      {Color? valueColor}) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(context.tr(labelKey),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: valueColor)),
          ),
        ],
      ),
    );
  }

  Widget _logTile(BuildContext context, OrderAuditLog log) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(log.action,
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ),
            Text(_fmt(log.createdAt),
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant)),
          ]),
          if (log.detail != null && log.detail!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(log.detail!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ),
          if (log.operator != null && log.operator!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                  '${context.tr('adminOrders.operator')}: ${log.operator}',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }

  static String _fmt(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    final d = DateTime.tryParse(raw);
    return d == null ? raw : formatDateTime(d.toLocal());
  }
}

// ==================== 退款弹层 ====================

class _RefundResult {
  const _RefundResult(
      {required this.amount,
      required this.reason,
      required this.deductBalance,
      required this.force});
  final num amount;
  final String reason;
  final bool deductBalance;
  final bool force;
}

class _RefundSheet extends StatefulWidget {
  const _RefundSheet({required this.order});
  final PaymentOrder order;

  @override
  State<_RefundSheet> createState() => _RefundSheetState();
}

class _RefundSheetState extends State<_RefundSheet> {
  late final TextEditingController _amount;
  late final TextEditingController _reason;
  bool _deductBalance = true;
  bool _force = false;

  @override
  void initState() {
    super.initState();
    final o = widget.order;
    final initial = (o.status == 'REFUND_REQUESTED' && o.refundAmount > 0)
        ? o.refundAmount
        : o.maxRefundable;
    _amount = TextEditingController(text: initial.toStringAsFixed(2));
    _reason = TextEditingController(text: o.refundRequestReason ?? '');
  }

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('adminOrders.refundOrder'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            // 订单信息
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(children: [
                _infoRow(context, context.tr('adminOrders.orderId'), '#${o.id}'),
                _infoRow(context, context.tr('adminOrders.credited'),
                    '${o.amountSymbol}${o.amount.toStringAsFixed(2)}'),
                _infoRow(context, context.tr('adminOrders.payAmount'),
                    '¥${o.payAmount.toStringAsFixed(2)}'),
                if (o.actuallyRefunded > 0)
                  _infoRow(context, context.tr('adminOrders.alreadyRefunded'),
                      '${o.amountSymbol}${o.actuallyRefunded.toStringAsFixed(2)}',
                      valueColor: scheme.error),
              ]),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _deductBalance,
              onChanged: (v) => setState(() => _deductBalance = v ?? true),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(context.tr('adminOrders.deductBalance')),
              subtitle: Text(context.tr('adminOrders.deductBalanceHint')),
            ),
            if (!_deductBalance)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(context.tr('adminOrders.noDeduction'),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.primary)),
              ),
            const SizedBox(height: 4),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: context.tr('adminOrders.refundAmount'),
                prefixText: '${o.amountSymbol} ',
                helperText:
                    '${context.tr('adminOrders.maxRefundable')}: ${o.amountSymbol}${o.maxRefundable.toStringAsFixed(2)}',
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reason,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: context.tr('adminOrders.refundReason'),
                hintText: context.tr('adminOrders.refundReasonHint'),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _force,
              onChanged: (v) => setState(() => _force = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(context.tr('adminOrders.forceRefund'),
                  style: TextStyle(color: scheme.error)),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.tr('common.cancel')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: scheme.error),
                  onPressed: _submit,
                  child: Text(context.tr('adminOrders.confirmRefund')),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final amount = num.tryParse(_amount.text.trim()) ?? 0;
    if (amount <= 0 || amount > widget.order.maxRefundable) {
      showAppToast(context, context.tr('adminOrders.invalidRefundAmount'),
          error: true);
      return;
    }
    if (_reason.text.trim().isEmpty) {
      showAppToast(context, context.tr('adminOrders.reasonRequired'),
          error: true);
      return;
    }
    Navigator.pop(
      context,
      _RefundResult(
        amount: amount,
        reason: _reason.text.trim(),
        deductBalance: _deductBalance,
        force: _force,
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: valueColor, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
