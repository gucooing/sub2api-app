import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../i18n/app_localizations.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../groups/providers/admin_groups_providers.dart';
import '../data/admin_channels_api.dart';
import '../providers/admin_channels_providers.dart';

const _billingSources = ['requested', 'upstream', 'channel_mapped'];
const _billingModes = ['token', 'per_request', 'image'];

/// 价格换算:存储为 per-token,编辑用每百万 token。
num? _toMTok(num? perToken) => perToken == null ? null : perToken * 1000000;
num? _toPerToken(num? mtok) => mtok == null ? null : mtok / 1000000;

/// 一条模型定价草稿(可变)。
class _PricingDraft {
  _PricingDraft({
    required this.id,
    this.platform = 'anthropic',
    this.modelsText = '',
    this.billingMode = 'token',
    this.input,
    this.output,
    this.cacheWrite,
    this.cacheRead,
    this.imageOut,
    this.perRequest,
    this.intervals = const [],
  });

  final int id;
  String platform;
  String modelsText;
  String billingMode;
  num? input; // 均为 per-MTok
  num? output;
  num? cacheWrite;
  num? cacheRead;
  num? imageOut;
  num? perRequest;
  List<Map<String, dynamic>> intervals;

  factory _PricingDraft.from(int id, ChannelModelPricing p) => _PricingDraft(
        id: id,
        platform: p.platform,
        modelsText: p.models.join(', '),
        billingMode: p.billingMode,
        input: _toMTok(p.inputPrice),
        output: _toMTok(p.outputPrice),
        cacheWrite: _toMTok(p.cacheWritePrice),
        cacheRead: _toMTok(p.cacheReadPrice),
        imageOut: _toMTok(p.imageOutputPrice),
        perRequest: p.perRequestPrice, // per_request 为每次请求价,不换算
        intervals: p.intervals,
      );

  ChannelModelPricing toPricing() => ChannelModelPricing(
        platform: platform,
        models: modelsText
            .split(RegExp(r'[,\s]+'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        billingMode: billingMode,
        inputPrice: _toPerToken(input),
        outputPrice: _toPerToken(output),
        cacheWritePrice: _toPerToken(cacheWrite),
        cacheReadPrice: _toPerToken(cacheRead),
        imageOutputPrice: _toPerToken(imageOut),
        perRequestPrice: perRequest,
        intervals: intervals,
      );
}

/// 渠道新增/编辑(名称/描述/状态/分组/计费模型来源/限制模型/账号统计计价 + 模型定价编辑)。
class ChannelEditPage extends ConsumerStatefulWidget {
  const ChannelEditPage({super.key, this.channelId});

  final int? channelId;

  bool get isEditing => channelId != null;

  @override
  ConsumerState<ChannelEditPage> createState() => _ChannelEditPageState();
}

class _ChannelEditPageState extends ConsumerState<ChannelEditPage> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _status = 'active';
  String _billingSource = 'requested';
  bool _restrictModels = false;
  bool _applyToAccountStats = false;
  final Set<int> _groupIds = {};
  final List<_PricingDraft> _pricing = [];
  int _seq = 0;
  Map<String, dynamic> _raw = const {};

  bool _loadingDetail = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadingDetail = true);
    try {
      final c =
          await ref.read(adminChannelsApiProvider).getById(widget.channelId!);
      if (!mounted) return;
      _nameCtrl.text = c.name;
      _descCtrl.text = c.description;
      _status = c.status;
      _billingSource = c.billingModelSource;
      _restrictModels = c.restrictModels;
      _applyToAccountStats = c.applyPricingToAccountStats;
      _groupIds
        ..clear()
        ..addAll(c.groupIds);
      _pricing
        ..clear()
        ..addAll([for (final p in c.modelPricing) _PricingDraft.from(_seq++, p)]);
      _raw = c.raw;
      setState(() => _loadingDetail = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingDetail = false);
      showAppToast(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(adminGroupsFullProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(
            widget.isEditing ? 'adminChannels.editTitle' : 'adminChannels.create')),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(context.tr('common.save')),
          ),
        ],
      ),
      body: _loadingDetail
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: context.tr('adminChannels.name'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _descCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: context.tr('adminChannels.description'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _billingSource,
                  decoration: InputDecoration(
                    labelText: context.tr('adminChannels.billingSource'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final s in _billingSources)
                      DropdownMenuItem(
                          value: s,
                          child: Text(context.tr('adminChannels.source_$s'))),
                  ],
                  onChanged: (v) => setState(() => _billingSource = v ?? 'requested'),
                ),
                if (widget.isEditing) ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: InputDecoration(
                      labelText: context.tr('adminChannels.status'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      for (final s in ['active', 'disabled'])
                        DropdownMenuItem(
                            value: s,
                            child: Text(context.tr('adminChannels.status_$s'))),
                    ],
                    onChanged: (v) => setState(() => _status = v ?? 'active'),
                  ),
                ],
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.tr('adminChannels.restrictModels')),
                  subtitle: Text(context.tr('adminChannels.restrictModelsHint')),
                  value: _restrictModels,
                  onChanged: (v) => setState(() => _restrictModels = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.tr('adminChannels.applyToAccountStats')),
                  subtitle:
                      Text(context.tr('adminChannels.applyToAccountStatsHint')),
                  value: _applyToAccountStats,
                  onChanged: (v) => setState(() => _applyToAccountStats = v),
                ),
                const SizedBox(height: 8),
                Text(context.tr('adminChannels.groups'),
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 6),
                if (groups.isEmpty)
                  Text(context.tr('adminChannels.noGroups'),
                      style: Theme.of(context).textTheme.bodySmall)
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final g in groups)
                        FilterChip(
                          label: Text(g.name),
                          selected: _groupIds.contains(g.id),
                          onSelected: (sel) => setState(() {
                            if (sel) {
                              _groupIds.add(g.id);
                            } else {
                              _groupIds.remove(g.id);
                            }
                          }),
                        ),
                    ],
                  ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: Text(context.tr('adminChannels.modelPricing'),
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(
                        () => _pricing.add(_PricingDraft(id: _seq++))),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(context.tr('adminChannels.addPricing')),
                  ),
                ]),
                for (var i = 0; i < _pricing.length; i++)
                  _pricingCard(context, i),
              ],
            ),
    );
  }

  Widget _pricingCard(BuildContext context, int i) {
    final scheme = Theme.of(context).colorScheme;
    final p = _pricing[i];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: TextFormField(
                  key: ValueKey('p-${p.id}-platform'),
                  initialValue: p.platform,
                  decoration: InputDecoration(
                    labelText: context.tr('adminChannels.platform'),
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) => p.platform = v.trim(),
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, size: 20, color: scheme.error),
                onPressed: () => setState(() => _pricing.removeAt(i)),
              ),
            ]),
            const SizedBox(height: 8),
            TextFormField(
              key: ValueKey('p-${p.id}-models'),
              initialValue: p.modelsText,
              decoration: InputDecoration(
                labelText: context.tr('adminChannels.models'),
                helperText: context.tr('adminChannels.modelsHint'),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => p.modelsText = v,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: p.billingMode,
              decoration: InputDecoration(
                labelText: context.tr('adminChannels.billingMode'),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final m in _billingModes)
                  DropdownMenuItem(
                      value: m, child: Text(context.tr('adminChannels.mode_$m'))),
              ],
              onChanged: (v) => setState(() => p.billingMode = v ?? 'token'),
            ),
            const SizedBox(height: 8),
            Text(context.tr('adminChannels.priceHint'),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            if (p.billingMode == 'per_request')
              _priceField(context, p, 'perRequest', 'adminChannels.perRequest',
                  perToken: false)
            else ...[
              Row(children: [
                Expanded(
                    child: _priceField(
                        context, p, 'input', 'adminChannels.pInput')),
                const SizedBox(width: 8),
                Expanded(
                    child: _priceField(
                        context, p, 'output', 'adminChannels.pOutput')),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: _priceField(
                        context, p, 'cacheWrite', 'adminChannels.pCacheWrite')),
                const SizedBox(width: 8),
                Expanded(
                    child: _priceField(
                        context, p, 'cacheRead', 'adminChannels.pCacheRead')),
              ]),
              if (p.billingMode == 'image') ...[
                const SizedBox(height: 8),
                _priceField(
                    context, p, 'imageOut', 'adminChannels.pImageOut'),
              ],
            ],
            if (p.intervals.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                  context.tr('adminChannels.intervalsPreserved',
                      params: {'n': '${p.intervals.length}'}),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _priceField(
      BuildContext context, _PricingDraft p, String field, String labelKey,
      {bool perToken = true}) {
    num? current = switch (field) {
      'input' => p.input,
      'output' => p.output,
      'cacheWrite' => p.cacheWrite,
      'cacheRead' => p.cacheRead,
      'imageOut' => p.imageOut,
      'perRequest' => p.perRequest,
      _ => null,
    };
    return TextFormField(
      key: ValueKey('p-${p.id}-$field'),
      initialValue: current == null ? '' : '$current',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: context.tr(labelKey),
        prefixText: '\$ ',
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      onChanged: (v) {
        final n = num.tryParse(v.trim());
        switch (field) {
          case 'input':
            p.input = n;
          case 'output':
            p.output = n;
          case 'cacheWrite':
            p.cacheWrite = n;
          case 'cacheRead':
            p.cacheRead = n;
          case 'imageOut':
            p.imageOut = n;
          case 'perRequest':
            p.perRequest = n;
        }
      },
    );
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      showAppToast(context, context.tr('adminChannels.errName'), error: true);
      return;
    }
    setState(() => _saving = true);
    final body = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'group_ids': _groupIds.toList(),
      'billing_model_source': _billingSource,
      'restrict_models': _restrictModels,
      'apply_pricing_to_account_stats': _applyToAccountStats,
      'model_pricing': [for (final p in _pricing) p.toPricing().toJson()],
      // 保留本端未编辑的复杂字段,避免丢失。
      'model_mapping': _raw['model_mapping'] ?? <String, dynamic>{},
      'account_stats_pricing_rules':
          _raw['account_stats_pricing_rules'] ?? <dynamic>[],
      if (_raw['features_config'] != null)
        'features_config': _raw['features_config'],
    };
    if (widget.isEditing) body['status'] = _status;
    try {
      final api = ref.read(adminChannelsApiProvider);
      if (widget.isEditing) {
        await api.update(widget.channelId!, body);
      } else {
        await api.create(body);
      }
      if (!mounted) return;
      showAppToast(context, context.tr('common.done'));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppToast(context, '$e', error: true);
    }
  }
}
