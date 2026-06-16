import 'package:flutter/material.dart';

import '../../../../../i18n/app_localizations.dart';
import '../../../../../shared/widgets/app_toast.dart';
import '../../../../../shared/widgets/pill_segmented.dart';
import '../../data/account_model_mapping.dart';

/// 模型限制编辑值:白名单 + 映射两份列表始终并存(保存时按 combined 合并),
/// [mode] 仅决定 UI 当前显示哪个编辑器。
class ModelRestrictionValue {
  ModelRestrictionValue({
    this.mode = ModelRestrictionMode.whitelist,
    List<String>? allowedModels,
    List<ModelMappingEntry>? mappings,
  })  : allowedModels = allowedModels ?? [],
        mappings = mappings ?? [];

  ModelRestrictionMode mode;
  List<String> allowedModels;
  List<ModelMappingEntry> mappings;

  /// 由 `credentials.model_mapping` 反解初始值,并推导初始 UI 模式。
  factory ModelRestrictionValue.fromMapping(Map<String, dynamic>? mapping) {
    final split = splitModelMappingObject(mapping);
    final mode = (split.modelMappings.isNotEmpty && split.allowedModels.isEmpty)
        ? ModelRestrictionMode.mapping
        : ModelRestrictionMode.whitelist;
    return ModelRestrictionValue(
      mode: mode,
      allowedModels: split.allowedModels,
      mappings: split.modelMappings,
    );
  }

  /// 合并为可提交的 model_mapping(无条目返回 null)。
  Map<String, String>? build() =>
      buildModelMappingObject(ModelRestrictionMode.combined, allowedModels, mappings);
}

/// 模型限制区块(对照 web EditAccountModal 的「模型限制」)。
///
/// - 普通平台:白名单 / 映射 两种模式切换。
/// - Antigravity([mappingOnly]=true):仅映射,支持通配符与「同步上游模型」。
class ModelRestrictionSection extends StatefulWidget {
  const ModelRestrictionSection({
    super.key,
    required this.platform,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.mappingOnly = false,
    this.onSyncUpstream,
  });

  final String platform;
  final ModelRestrictionValue value;
  final ValueChanged<ModelRestrictionValue> onChanged;
  final bool enabled;

  /// Antigravity 专用:仅映射模式 + 通配符校验。
  final bool mappingOnly;

  /// 「同步上游模型」回调,返回上游模型 id 列表(null 表示不显示该按钮)。
  final Future<List<String>> Function()? onSyncUpstream;

  @override
  State<ModelRestrictionSection> createState() => _ModelRestrictionSectionState();
}

class _ModelRestrictionSectionState extends State<ModelRestrictionSection> {
  late ModelRestrictionMode _mode;
  late List<String> _allowed;
  late List<_MapRow> _rows;
  final _customCtrl = TextEditingController();
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _mode = widget.mappingOnly ? ModelRestrictionMode.mapping : widget.value.mode;
    _allowed = [...widget.value.allowedModels];
    _rows = [
      for (final m in widget.value.mappings)
        _MapRow(from: m.from, to: m.to),
    ];
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _emit() {
    widget.onChanged(ModelRestrictionValue(
      mode: _mode,
      allowedModels: [..._allowed],
      mappings: [
        for (final r in _rows)
          ModelMappingEntry(from: r.from.text, to: r.to.text),
      ],
    ));
  }

  void _toggleAllowed(String model, bool selected) {
    setState(() {
      if (selected) {
        if (!_allowed.contains(model)) _allowed.add(model);
      } else {
        _allowed.remove(model);
      }
    });
    _emit();
  }

  void _addCustom() {
    final m = _customCtrl.text.trim();
    if (m.isEmpty) return;
    if (!_allowed.contains(m)) {
      setState(() => _allowed.add(m));
      _emit();
    }
    _customCtrl.clear();
  }

  void _addRow([String from = '', String to = '']) {
    setState(() => _rows.add(_MapRow(from: from, to: to)));
    _emit();
  }

  void _removeRow(int i) {
    setState(() {
      _rows.removeAt(i).dispose();
    });
    _emit();
  }

  void _addPreset(PresetMapping p) {
    if (_rows.any((r) => r.from.text == p.from)) {
      showAppToast(context,
          context.tr('adminAccounts.model.mappingExists', params: {'model': p.from}));
      return;
    }
    _addRow(p.from, p.to);
  }

  Future<void> _sync() async {
    final fn = widget.onSyncUpstream;
    if (fn == null || _syncing) return;
    setState(() => _syncing = true);
    try {
      final models = await fn();
      var added = 0;
      for (final m in models) {
        if (!_rows.any((r) => r.from.text == m)) {
          _rows.add(_MapRow(from: m, to: m));
          added++;
        }
      }
      if (mounted) {
        setState(() {});
        _emit();
        showAppToast(
            context,
            context.tr('adminAccounts.model.syncDone',
                params: {'count': '$added', 'total': '${models.length}'}));
      }
    } catch (e) {
      if (mounted) showAppToast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.mappingOnly) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: PillSegmented<ModelRestrictionMode>(
              selected: _mode,
              onChanged: widget.enabled
                  ? (m) {
                      setState(() => _mode = m);
                      _emit();
                    }
                  : (_) {},
              options: [
                (ModelRestrictionMode.whitelist,
                    context.tr('adminAccounts.model.whitelist')),
                (ModelRestrictionMode.mapping,
                    context.tr('adminAccounts.model.mapping')),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_mode == ModelRestrictionMode.whitelist && !widget.mappingOnly)
          _whitelistEditor(theme)
        else
          _mappingEditor(theme),
      ],
    );
  }

  Widget _whitelistEditor(ThemeData theme) {
    final candidates = <String>{
      ...getModelsByPlatform(widget.platform),
      ..._allowed,
    }.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final m in candidates)
              FilterChip(
                label: Text(m),
                selected: _allowed.contains(m),
                onSelected:
                    widget.enabled ? (s) => _toggleAllowed(m, s) : null,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _customCtrl,
              enabled: widget.enabled,
              decoration: InputDecoration(
                isDense: true,
                border: const OutlineInputBorder(),
                hintText: context.tr('adminAccounts.model.customHint'),
              ),
              onSubmitted: (_) => _addCustom(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: widget.enabled ? _addCustom : null,
            icon: const Icon(Icons.add),
          ),
        ]),
        const SizedBox(height: 6),
        Text(
          _allowed.isEmpty
              ? context.tr('adminAccounts.model.allModels')
              : context.tr('adminAccounts.model.selectedCount',
                  params: {'count': '${_allowed.length}'}),
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _mappingEditor(ThemeData theme) {
    final presets = getPresetMappingsByPlatform(widget.platform);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.mappingOnly && widget.onSyncUpstream != null) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: widget.enabled && !_syncing ? _sync : null,
              icon: _syncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sync, size: 18),
              label: Text(context.tr('adminAccounts.model.syncUpstream')),
            ),
          ),
          const SizedBox(height: 8),
        ],
        for (var i = 0; i < _rows.length; i++) _mappingRow(theme, i),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: widget.enabled ? () => _addRow() : null,
          icon: const Icon(Icons.add, size: 18),
          label: Text(context.tr('adminAccounts.model.addMapping')),
        ),
        if (presets.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final p in presets)
                ActionChip(
                  label: Text('+ ${p.label}'),
                  onPressed: widget.enabled ? () => _addPreset(p) : null,
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _mappingRow(ThemeData theme, int i) {
    final row = _rows[i];
    final fromInvalid =
        widget.mappingOnly && !isValidWildcardPattern(row.from.text);
    final toInvalid = widget.mappingOnly && row.to.text.contains('*');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: row.from,
                enabled: widget.enabled,
                decoration: InputDecoration(
                  isDense: true,
                  border: const OutlineInputBorder(),
                  hintText: context.tr('adminAccounts.model.requestModel'),
                  errorText: fromInvalid ? '' : null,
                ),
                onChanged: (_) => setState(_emit),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.arrow_forward, size: 18),
            ),
            Expanded(
              child: TextField(
                controller: row.to,
                enabled: widget.enabled,
                decoration: InputDecoration(
                  isDense: true,
                  border: const OutlineInputBorder(),
                  hintText: context.tr('adminAccounts.model.actualModel'),
                  errorText: toInvalid ? '' : null,
                ),
                onChanged: (_) => setState(_emit),
              ),
            ),
            IconButton(
              onPressed: widget.enabled ? () => _removeRow(i) : null,
              icon: Icon(Icons.delete_outline,
                  size: 20, color: theme.colorScheme.error),
            ),
          ]),
          if (fromInvalid)
            Text(context.tr('adminAccounts.model.wildcardOnlyAtEnd'),
                style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
          if (toInvalid)
            Text(context.tr('adminAccounts.model.targetNoWildcard'),
                style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
        ],
      ),
    );
  }
}

class _MapRow {
  _MapRow({String from = '', String to = ''})
      : from = TextEditingController(text: from),
        to = TextEditingController(text: to);
  final TextEditingController from;
  final TextEditingController to;
  void dispose() {
    from.dispose();
    to.dispose();
  }
}
