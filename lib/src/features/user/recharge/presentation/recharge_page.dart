import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/session/session_controller.dart';
import '../../../../i18n/app_localizations.dart';
import '../../../../shared/format/formatters.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/brand_header.dart';
import '../../../../shared/widgets/responsive.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../data/recharge_api.dart';
import '../providers/recharge_providers.dart';
import 'order_visuals.dart';

/// 充值页:余额充值 / 套餐 + 支付方式 → 下单 → 二维码 / 跳转支付 + 手动核验;附订单历史。
class RechargePage extends ConsumerStatefulWidget {
  const RechargePage({super.key});

  @override
  ConsumerState<RechargePage> createState() => _RechargePageState();
}

class _RechargePageState extends ConsumerState<RechargePage> {
  final _amountController = TextEditingController();

  /// 选中的支付方式 key。
  String? _method;

  /// 选中的套餐(null = 余额充值模式)。
  PaymentPlan? _plan;
  bool _submitting = false;

  static const _quickAmounts = [10.0, 30.0, 50.0, 100.0, 200.0, 500.0];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final infoAsync = ref.watch(checkoutInfoProvider);
    final user = ref.watch(sessionControllerProvider).user;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('recharge.title'))),
      body: ResponsiveCenter(
        child: AsyncValueView(
        value: infoAsync,
        onRetry: () => ref.invalidate(checkoutInfoProvider),
        builder: (context, info) {
          // 默认选第一个可用支付方式。
          _method ??= info.methods.isNotEmpty ? info.methods.first.key : null;
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(checkoutInfoProvider);
              ref.invalidate(myOrdersProvider);
              await ref.read(checkoutInfoProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                BrandHeader(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr('recharge.balance'),
                          style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 6),
                      Text(
                        formatCost(user?.balance ?? 0),
                        style: const TextStyle(
                            fontSize: 32, fontWeight: FontWeight.w700),
                      ),
                      if (info.balanceRechargeMultiplier != 1) ...[
                        const SizedBox(height: 4),
                        Text(
                          context.tr('recharge.multiplierHint', params: {
                            'x': info.balanceRechargeMultiplier
                                .toStringAsFixed(2)
                          }),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (!info.balanceDisabled) _buildAmountCard(context, info),
                if (info.plans.isNotEmpty) _buildPlansSection(context, info),
                _buildMethodCard(context, info),
                _buildPayButton(context, info),
                const SizedBox(height: 20),
                _buildHistory(context),
              ],
            ),
          );
        },
        ),
      ),
    );
  }

  Widget _buildAmountCard(BuildContext context, CheckoutInfo info) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('recharge.amount'),
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in _quickAmounts)
                    ChoiceChip(
                      label: Text(formatCost(a, decimals: 0)),
                      selected: _plan == null &&
                          _amountController.text == a.toStringAsFixed(0),
                      onSelected: (_) {
                        setState(() {
                          _plan = null;
                          _amountController.text = a.toStringAsFixed(0);
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) {
                  if (_plan != null) setState(() => _plan = null);
                },
                decoration: InputDecoration(
                  prefixText: '\$ ',
                  labelText: context.tr('recharge.customAmount'),
                  border: const OutlineInputBorder(),
                  helperText: _amountRangeHint(context, info),
                ),
              ),
              if (info.balanceRechargeMultiplier != 1 &&
                  _enteredAmount() != null) ...[
                const SizedBox(height: 8),
                Text(
                  context.tr('recharge.received', params: {
                    'amount': formatCost(
                        _enteredAmount()! * info.balanceRechargeMultiplier)
                  }),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlansSection(BuildContext context, CheckoutInfo info) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: context.tr('recharge.plans')),
          for (final plan in info.plans) _PlanCard(
            plan: plan,
            selected: _plan?.id == plan.id,
            onTap: () => setState(() => _plan = plan),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodCard(BuildContext context, CheckoutInfo info) {
    if (info.methods.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Text(
                context.tr('recharge.noMethods'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Text(context.tr('recharge.payMethod'),
                    style: Theme.of(context).textTheme.titleSmall),
              ),
              for (final m in info.methods)
                _MethodTile(
                  method: m,
                  selected: _method == m.key,
                  onTap: () => setState(() => _method = m.key),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPayButton(BuildContext context, CheckoutInfo info) {
    final canPay = _method != null &&
        (_plan != null || (_enteredAmount() != null && _enteredAmount()! > 0));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: FilledButton(
        onPressed: (!canPay || _submitting) ? null : () => _submit(info),
        child: _submitting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(context.tr('recharge.pay')),
      ),
    );
  }

  Widget _buildHistory(BuildContext context) {
    final ordersAsync = ref.watch(myOrdersProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: context.tr('recharge.history'),
            trailing: IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: () => ref.invalidate(myOrdersProvider),
            ),
          ),
          ordersAsync.when(
            data: (orders) {
              if (orders.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        context.tr('recharge.historyEmpty'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (final o in orders)
                    _OrderTile(
                      order: o,
                      onVerify: () => _verify(o),
                    ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                e is ApiException
                    ? e.localizedMessage(context)
                    : context.tr('common.unknownError'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double? _enteredAmount() {
    if (_plan != null) return _plan!.price;
    return double.tryParse(_amountController.text.trim());
  }

  String? _amountRangeHint(BuildContext context, CheckoutInfo info) {
    if (info.globalMin <= 0 && info.globalMax <= 0) return null;
    final min = info.globalMin > 0 ? formatCost(info.globalMin, decimals: 0) : '';
    final max = info.globalMax > 0 ? formatCost(info.globalMax, decimals: 0) : '';
    return context.tr('recharge.amountRange', params: {'min': min, 'max': max});
  }

  Future<void> _submit(CheckoutInfo info) async {
    final amount = _enteredAmount();
    if (amount == null || amount <= 0 || _method == null) return;
    // 余额模式校验范围。
    if (_plan == null) {
      if (info.globalMin > 0 && amount < info.globalMin ||
          info.globalMax > 0 && amount > info.globalMax) {
        showAppToast(context, context.tr('recharge.amountInvalid'));
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      final result = await ref.read(rechargeApiProvider).createOrder(
            amount: amount,
            paymentType: _method!,
            orderType: _plan != null ? 'subscription' : 'balance',
            planId: _plan?.id,
          );
      ref.invalidate(myOrdersProvider);
      if (!mounted) return;
      await _presentPayResult(result);
    } catch (e) {
      if (!mounted) return;
      showAppToast(
        context,
        e is ApiException
            ? (e.serverMessage ?? context.tr('common.unknownError'))
            : context.tr('common.unknownError'),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// 展示支付结果:有二维码弹码,有 pay_url 跳浏览器,统一给「我已支付/核验」入口。
  Future<void> _presentPayResult(CreateOrderResult result) async {
    final qr = result.qrCode;
    final url = result.payUrl;

    if (qr == null && url != null) {
      // 直接跳转支付页(支付宝/Stripe 等)。
      final uri = Uri.tryParse(url);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _PayResultSheet(
        result: result,
        onVerify: () async {
          final ok = await _verifyByTradeNo(result.outTradeNo);
          if (ok && sheetContext.mounted) Navigator.of(sheetContext).pop();
        },
        onOpenUrl: url == null
            ? null
            : () async {
                final uri = Uri.tryParse(url);
                if (uri != null) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
      ),
    );
  }

  Future<void> _verify(PaymentOrder order) => _verifyByTradeNo(order.outTradeNo);

  Future<bool> _verifyByTradeNo(String? outTradeNo) async {
    if (outTradeNo == null || outTradeNo.isEmpty) return false;
    try {
      final order = await ref.read(rechargeApiProvider).verifyOrder(outTradeNo);
      ref.invalidate(myOrdersProvider);
      // 充值成功刷新余额。
      await ref.read(sessionControllerProvider.notifier).refreshUser();
      if (!mounted) return false;
      final done = order.status.toUpperCase() == 'COMPLETED';
      showAppToast(
        context,
        done
            ? context.tr('recharge.paySuccess')
            : context.tr('recharge.payPending'),
      );
      return done;
    } catch (e) {
      if (!mounted) return false;
      showAppToast(
        context,
        e is ApiException
            ? (e.serverMessage ?? context.tr('common.unknownError'))
            : context.tr('common.unknownError'),
      );
      return false;
    }
  }
}

/// 支付方式选择项(自绘单选,避免 RadioListTile 弃用 API)。
class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final PaymentMethodLimit method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? scheme.primary : scheme.outline,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(paymentMethodLabel(context, method.key))),
            if (method.feeRate > 0)
              Text(
                context.tr('recharge.feeRate',
                    params: {'rate': (method.feeRate * 100).toStringAsFixed(1)}),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 套餐卡片。
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final PaymentPlan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? scheme.primary : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? scheme.primary : scheme.outline,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    if (plan.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        plan.description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      context.tr('recharge.planValidity', params: {
                        'days': plan.validityDays.toString()
                      }),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatCost(plan.price),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700),
                  ),
                  if (plan.originalPrice != null &&
                      plan.originalPrice! > plan.price)
                    Text(
                      formatCost(plan.originalPrice!),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            decoration: TextDecoration.lineThrough,
                          ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 订单历史项。
class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order, required this.onVerify});

  final PaymentOrder order;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pending = order.status.toUpperCase() == 'PENDING';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        formatCost(order.amount),
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      StatusPill(
                        label: orderStatusLabel(context, order.status),
                        tone: orderStatusTone(order.status),
                        dense: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${paymentMethodLabel(context, order.paymentType)}'
                    '${order.createdAt != null ? ' · ${formatDateTime(order.createdAt!)}' : ''}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            if (pending)
              TextButton(
                onPressed: onVerify,
                child: Text(context.tr('recharge.verify')),
              ),
          ],
        ),
      ),
    );
  }
}

/// 支付结果底部弹层(二维码 + 核验)。
class _PayResultSheet extends StatelessWidget {
  const _PayResultSheet({
    required this.result,
    required this.onVerify,
    this.onOpenUrl,
  });

  final CreateOrderResult result;
  final Future<void> Function() onVerify;
  final Future<void> Function()? onOpenUrl;

  @override
  Widget build(BuildContext context) {
    final qr = result.qrCode;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.tr('recharge.payTitle'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              formatCost(result.payAmount > 0 ? result.payAmount : result.amount),
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            if (qr != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data: qr,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.tr('recharge.qrHint'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else ...[
              Text(
                context.tr('recharge.payInBrowser'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (onOpenUrl != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onOpenUrl,
                  icon: const Icon(Icons.open_in_new),
                  label: Text(context.tr('recharge.openPayPage')),
                ),
              ],
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onVerify,
                child: Text(context.tr('recharge.verifyDone')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
