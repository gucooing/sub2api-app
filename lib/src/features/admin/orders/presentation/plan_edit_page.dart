import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../i18n/app_localizations.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../groups/data/admin_groups_api.dart';
import '../../groups/providers/admin_groups_providers.dart';
import '../data/admin_payment_api.dart';
import '../providers/admin_payment_providers.dart';

/// 订阅计划 新增/编辑(对照 web PlanEditDialog)。
class PlanEditPage extends ConsumerStatefulWidget {
  const PlanEditPage({super.key, this.planId});

  final int? planId;

  @override
  ConsumerState<PlanEditPage> createState() => _PlanEditPageState();
}

class _PlanEditPageState extends ConsumerState<PlanEditPage> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _originalPrice = TextEditingController();
  final _validityDays = TextEditingController(text: '30');
  final _sortOrder = TextEditingController(text: '0');
  final _features = TextEditingController();

  int? _groupId;
  String _validityUnit = 'days';
  bool _forSale = true;
  bool _saving = false;
  bool _initialized = false;

  bool get _isEdit => widget.planId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final plans = ref.read(adminPlansProvider).value;
      final p = plans?.where((e) => e.id == widget.planId).firstOrNull;
      if (p != null) _fill(p);
    }
    _initialized = true;
  }

  void _fill(SubscriptionPlan p) {
    _name.text = p.name;
    _description.text = p.description;
    _price.text = p.price.toString();
    _originalPrice.text =
        (p.originalPrice != null && p.originalPrice! > 0) ? '${p.originalPrice}' : '';
    _validityDays.text = '${p.validityDays}';
    _sortOrder.text = '${p.sortOrder}';
    _features.text = p.features.join('\n');
    _groupId = p.groupId;
    _validityUnit = p.validityUnit;
    _forSale = p.forSale;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _originalPrice.dispose();
    _validityDays.dispose();
    _sortOrder.dispose();
    _features.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 编辑时若计划列表此前未加载(直接进入),补取一次。
    final plansAsync = ref.watch(adminPlansProvider);
    if (_isEdit && _groupId == null && _initialized) {
      final p = plansAsync.value?.where((e) => e.id == widget.planId).firstOrNull;
      if (p != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _groupId == null) setState(() => _fill(p));
        });
      }
    }
    final groups = (ref.watch(adminGroupsFullProvider).value ?? const [])
        .where((g) => g.subscriptionType == 'subscription')
        .toList();
    final selectedGroup = _groupId == null
        ? null
        : groups.where((g) => g.id == _groupId).firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(
            _isEdit ? 'adminOrders.editPlan' : 'adminOrders.createPlan')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _field(_name, 'adminOrders.planName', required: true),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _groupId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: '${context.tr('adminOrders.group')} *',
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            hint: Text(context.tr('adminOrders.selectGroup')),
            items: [
              for (final g in groups)
                DropdownMenuItem(
                  value: g.id,
                  child: Text('${g.name} — ${g.platform} (×${g.rateMultiplier})',
                      overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => _groupId = v),
          ),
          if (selectedGroup != null) ...[
            const SizedBox(height: 8),
            _groupInfo(context, selectedGroup),
          ],
          const SizedBox(height: 12),
          _field(_description, 'adminOrders.planDescription',
              required: true, maxLines: 2),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _field(_price, 'adminOrders.price',
                    required: true, number: true, prefix: '\$ ')),
            const SizedBox(width: 12),
            Expanded(
                child: _field(_originalPrice, 'adminOrders.originalPrice',
                    number: true, prefix: '\$ ')),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _field(_validityDays, 'adminOrders.validityDays',
                    required: true, number: true)),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _validityUnit,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: context.tr('adminOrders.validityUnit'),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final u in const ['days', 'weeks', 'months'])
                    DropdownMenuItem(
                        value: u, child: Text(context.tr('adminOrders.unit_$u'))),
                ],
                onChanged: (v) => setState(() => _validityUnit = v ?? 'days'),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          _field(_sortOrder, 'adminOrders.sortOrder', number: true),
          const SizedBox(height: 12),
          _field(_features, 'adminOrders.features',
              maxLines: 3, hint: context.tr('adminOrders.featuresHint')),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _forSale,
            onChanged: (v) => setState(() => _forSale = v),
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('adminOrders.forSale')),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(context.tr('common.save')),
          ),
        ],
      ),
    );
  }

  Widget _groupInfo(BuildContext context, AdminGroup g) {
    final scheme = Theme.of(context).colorScheme;
    String limit(num? v) =>
        v == null ? context.tr('adminOrders.unlimited') : '\$$v';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(spacing: 16, runSpacing: 4, children: [
        _infoItem(context, context.tr('adminOrders.dailyLimit'),
            limit(g.dailyLimitUsd)),
        _infoItem(context, context.tr('adminOrders.weeklyLimit'),
            limit(g.weeklyLimitUsd)),
        _infoItem(context, context.tr('adminOrders.monthlyLimit'),
            limit(g.monthlyLimitUsd)),
      ]),
    );
  }

  Widget _infoItem(BuildContext context, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text('$label: ',
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: scheme.onSurfaceVariant)),
      Text(value,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _field(TextEditingController c, String labelKey,
      {bool required = false,
      bool number = false,
      int maxLines = 1,
      String? prefix,
      String? hint}) {
    return TextField(
      controller: c,
      keyboardType:
          number ? const TextInputType.numberWithOptions(decimal: true) : null,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: required
            ? '${context.tr(labelKey)} *'
            : context.tr(labelKey),
        prefixText: prefix,
        hintText: hint,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Future<void> _save() async {
    if (_groupId == null) {
      showAppToast(context, context.tr('adminOrders.groupRequired'), error: true);
      return;
    }
    final price = num.tryParse(_price.text.trim()) ?? 0;
    if (price <= 0) {
      showAppToast(context, context.tr('adminOrders.priceRequired'), error: true);
      return;
    }
    final days = int.tryParse(_validityDays.text.trim()) ?? 0;
    if (days < 1) {
      showAppToast(context, context.tr('adminOrders.validityDaysRequired'),
          error: true);
      return;
    }
    final features = _features.text
        .split('\n')
        .map((f) => f.trim())
        .where((f) => f.isNotEmpty)
        .join('\n');
    final payload = <String, dynamic>{
      'name': _name.text.trim(),
      'group_id': _groupId,
      'description': _description.text.trim(),
      'price': price,
      'original_price': num.tryParse(_originalPrice.text.trim()) ?? 0,
      'validity_days': days,
      'validity_unit': _validityUnit,
      'sort_order': int.tryParse(_sortOrder.text.trim()) ?? 0,
      'for_sale': _forSale,
      'features': features,
    };
    setState(() => _saving = true);
    try {
      final api = ref.read(adminPaymentApiProvider);
      if (_isEdit) {
        await api.updatePlan(widget.planId!, payload);
      } else {
        await api.createPlan(payload);
      }
      ref.invalidate(adminPlansProvider);
      if (mounted) {
        showAppToast(context, context.tr('common.done'));
        context.pop();
      }
    } catch (e) {
      if (mounted) showAppToast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
