import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../i18n/app_localizations.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../groups/data/admin_groups_api.dart';
import '../../groups/providers/admin_groups_providers.dart';
import '../data/admin_risk_control_api.dart';
import '../providers/admin_risk_control_providers.dart';
import 'risk_logs_tab.dart' show pct;
import 'risk_status_tab.dart' show apiKeyTone;
import '../../../../shared/widgets/status_pill.dart';

/// 内容审核配置(对照 web RiskControlView 设置弹窗的全部分区)。
class RiskConfigPage extends ConsumerStatefulWidget {
  const RiskConfigPage({super.key});

  @override
  ConsumerState<RiskConfigPage> createState() => _RiskConfigPageState();
}

class _RiskConfigPageState extends ConsumerState<RiskConfigPage> {
  bool _initialized = false;
  bool _saving = false;

  // 基础
  bool _enabled = false;
  String _mode = 'pre_block';
  final _baseUrl = TextEditingController();
  final _model = TextEditingController();
  final _timeoutMs = TextEditingController(text: '3000');
  final _retryCount = TextEditingController(text: '2');
  final _sampleRate = TextEditingController(text: '100');

  // API 密钥
  final _apiKeysText = TextEditingController();
  String _apiKeysMode = 'append';
  bool _clearApiKey = false;
  int _apiKeyCount = 0;
  List<ContentModerationApiKeyStatus> _apiKeyStatuses = const [];
  final _pendingDeleteHashes = <String>{};
  final _testPrompt = TextEditingController();
  bool _testing = false;
  List<ContentModerationApiKeyStatus> _testedStatuses = const [];
  ModerationTestAuditResult? _testAudit;

  // 范围
  bool _allGroups = true;
  final _groupIds = <int>{};
  final _groupSearch = TextEditingController();
  String _modelFilterType = 'all';
  final _modelFilterText = TextEditingController();

  // 运行
  final _workerCount = TextEditingController(text: '4');
  final _queueSize = TextEditingController(text: '32768');
  bool _recordNonHits = false;
  bool _preHashCheck = false;

  // 响应
  final _blockStatus = TextEditingController(text: '403');
  final _blockMessage = TextEditingController();
  bool _emailOnHit = true;
  bool _autoBan = true;
  final _banThreshold = TextEditingController(text: '10');
  final _violationWindow = TextEditingController(text: '720');

  // 阈值
  final Map<String, TextEditingController> _thresholds = {};

  // 关键词
  String _keywordMode = 'keyword_and_api';
  final _blockedKeywords = TextEditingController();

  // 留存
  final _hitRetention = TextEditingController(text: '180');
  final _nonHitRetention = TextEditingController(text: '3');

  void _initFrom(ContentModerationConfig c) {
    _enabled = c.enabled;
    _mode = c.mode;
    _baseUrl.text = c.baseUrl;
    _model.text = c.model;
    _timeoutMs.text = '${c.timeoutMs}';
    _retryCount.text = '${c.retryCount}';
    _sampleRate.text = '${c.sampleRate}';
    _apiKeyCount = c.apiKeyCount;
    _apiKeyStatuses = c.apiKeyStatuses;
    _allGroups = c.allGroups;
    _groupIds
      ..clear()
      ..addAll(c.groupIds);
    _modelFilterType = c.modelFilter.type;
    _modelFilterText.text = c.modelFilter.models.join('\n');
    _workerCount.text = '${c.workerCount}';
    _queueSize.text = '${c.queueSize}';
    _recordNonHits = c.recordNonHits;
    _preHashCheck = c.preHashCheckEnabled;
    _blockStatus.text = '${c.blockStatus}';
    _blockMessage.text = c.blockMessage;
    _emailOnHit = c.emailOnHit;
    _autoBan = c.autoBanEnabled;
    _banThreshold.text = '${c.banThreshold}';
    _violationWindow.text = '${c.violationWindowHours}';
    _keywordMode = c.keywordBlockingMode;
    _blockedKeywords.text = c.blockedKeywords.join('\n');
    _hitRetention.text = '${c.hitRetentionDays}';
    _nonHitRetention.text = '${c.nonHitRetentionDays}';
    for (final cat in kRiskThresholdDefaults.keys) {
      // 配置存 0-1 分数,展示为百分比。
      final frac = c.thresholds[cat];
      final percent = frac != null
          ? (frac * 100)
          : (kRiskThresholdDefaults[cat] ?? 0);
      _thresholds[cat] = TextEditingController(
          text: _trimNum(percent));
    }
  }

  static String _trimNum(num v) {
    final d = v.toDouble();
    return d == d.roundToDouble() ? '${d.toInt()}' : '$d';
  }

  @override
  void dispose() {
    for (final c in [
      _baseUrl,
      _model,
      _timeoutMs,
      _retryCount,
      _sampleRate,
      _apiKeysText,
      _testPrompt,
      _groupSearch,
      _modelFilterText,
      _workerCount,
      _queueSize,
      _blockStatus,
      _blockMessage,
      _banThreshold,
      _violationWindow,
      _blockedKeywords,
      _hitRetention,
      _nonHitRetention,
    ]) {
      c.dispose();
    }
    for (final c in _thresholds.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(riskControlConfigProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('adminRisk.configTitle'))),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (c) {
          if (!_initialized) {
            _initFrom(c);
            _initialized = true;
          }
          return _form(context);
        },
      ),
      bottomNavigationBar: _initialized
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(context.tr('adminRisk.saveConfig')),
                ),
              ),
            )
          : null,
    );
  }

  Widget _form(BuildContext context) {
    final groups = (ref.watch(adminGroupsFullProvider).value ?? const [])
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        _section(context, 'adminRisk.tabBasic', [
          SwitchListTile(
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('adminRisk.enabled')),
            subtitle: Text(context.tr('adminRisk.enabledHint')),
          ),
          _dropdown(context, 'adminRisk.mode', _mode, kModerationModes,
              (v) => setState(() => _mode = v),
              labelOf: (v) => context.tr('adminRisk.mode_$v')),
          _text(_baseUrl, 'adminRisk.baseUrl'),
          _text(_model, 'adminRisk.model'),
          Row(children: [
            Expanded(child: _text(_timeoutMs, 'adminRisk.timeoutMs', number: true)),
            const SizedBox(width: 12),
            Expanded(child: _text(_retryCount, 'adminRisk.retryCount', number: true)),
          ]),
          _text(_sampleRate, 'adminRisk.sampleRate', number: true),
        ]),
        _section(context, 'adminRisk.tabApiKeys', _apiKeysSection(context)),
        _section(context, 'adminRisk.tabScope', _scopeSection(context, groups)),
        _section(context, 'adminRisk.tabRuntime', [
          Row(children: [
            Expanded(child: _text(_workerCount, 'adminRisk.workerCount', number: true)),
            const SizedBox(width: 12),
            Expanded(child: _text(_queueSize, 'adminRisk.queueSize', number: true)),
          ]),
          SwitchListTile(
            value: _recordNonHits,
            onChanged: (v) => setState(() => _recordNonHits = v),
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('adminRisk.recordNonHits')),
            subtitle: Text(context.tr('adminRisk.recordNonHitsHint')),
          ),
          SwitchListTile(
            value: _preHashCheck,
            onChanged: (v) => setState(() => _preHashCheck = v),
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('adminRisk.preHashCheck')),
            subtitle: Text(context.tr('adminRisk.preHashCheckHint')),
          ),
        ]),
        _section(context, 'adminRisk.tabResponse', [
          Row(children: [
            Expanded(child: _text(_blockStatus, 'adminRisk.blockStatus', number: true)),
          ]),
          _text(_blockMessage, 'adminRisk.blockMessage'),
          SwitchListTile(
            value: _emailOnHit,
            onChanged: (v) => setState(() => _emailOnHit = v),
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('adminRisk.emailOnHit')),
            subtitle: Text(context.tr('adminRisk.emailOnHitHint')),
          ),
          SwitchListTile(
            value: _autoBan,
            onChanged: (v) => setState(() => _autoBan = v),
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('adminRisk.autoBan')),
            subtitle: Text(context.tr('adminRisk.autoBanHint')),
          ),
          Row(children: [
            Expanded(child: _text(_banThreshold, 'adminRisk.banThreshold', number: true)),
            const SizedBox(width: 12),
            Expanded(
                child: _text(_violationWindow, 'adminRisk.violationWindowHours',
                    number: true)),
          ]),
        ]),
        _section(context, 'adminRisk.tabThresholds', _thresholdsSection(context)),
        _section(context, 'adminRisk.tabKeywords', _keywordsSection(context)),
        _section(context, 'adminRisk.tabRetention', [
          Row(children: [
            Expanded(child: _text(_hitRetention, 'adminRisk.hitRetentionDays', number: true)),
            const SizedBox(width: 12),
            Expanded(
                child: _text(_nonHitRetention, 'adminRisk.nonHitRetentionDays',
                    number: true)),
          ]),
        ]),
      ],
    );
  }

  List<Widget> _apiKeysSection(BuildContext context) {
    return [
      Text(context.tr('adminRisk.apiKeyCount', params: {'count': '$_apiKeyCount'}),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
      const SizedBox(height: 8),
      // 已存密钥(可标记删除)
      if (_apiKeyStatuses.isNotEmpty)
        for (final k in _apiKeyStatuses)
          _storedKeyRow(context, k),
      const SizedBox(height: 8),
      TextField(
        controller: _apiKeysText,
        maxLines: 3,
        enabled: !_clearApiKey,
        decoration: InputDecoration(
          labelText: context.tr('adminRisk.apiKeysInput'),
          hintText: context.tr('adminRisk.apiKeysPlaceholder'),
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      ),
      const SizedBox(height: 8),
      Row(children: [
        Text(context.tr('adminRisk.apiKeysWriteMode'),
            style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(width: 12),
        ChoiceChip(
          label: Text(context.tr('adminRisk.apiKeysModeAppend')),
          selected: _apiKeysMode == 'append',
          onSelected: _clearApiKey ? null : (_) => setState(() => _apiKeysMode = 'append'),
        ),
        const SizedBox(width: 6),
        ChoiceChip(
          label: Text(context.tr('adminRisk.apiKeysModeReplace')),
          selected: _apiKeysMode == 'replace',
          onSelected: _clearApiKey ? null : (_) => setState(() => _apiKeysMode = 'replace'),
        ),
      ]),
      SwitchListTile(
        value: _clearApiKey,
        onChanged: (v) => setState(() => _clearApiKey = v),
        contentPadding: EdgeInsets.zero,
        title: Text(context.tr('adminRisk.clearApiKey')),
        subtitle: Text(context.tr('adminRisk.clearApiKeyHint')),
      ),
      const Divider(height: 20),
      // 审核测试
      TextField(
        controller: _testPrompt,
        maxLines: 2,
        decoration: InputDecoration(
          labelText: context.tr('adminRisk.auditTestInput'),
          hintText: context.tr('adminRisk.auditTestPromptPlaceholder'),
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: _testing ? null : _runTest,
          icon: _testing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.bolt_outlined, size: 18),
          label: Text(context.tr('adminRisk.testApiKeys')),
        ),
      ),
      if (_testAudit != null) ...[
        const SizedBox(height: 8),
        _auditResult(context, _testAudit!),
      ],
      if (_testedStatuses.isNotEmpty) ...[
        const SizedBox(height: 8),
        for (final k in _testedStatuses) _testedKeyRow(context, k),
      ],
    ];
  }

  Widget _storedKeyRow(BuildContext context, ContentModerationApiKeyStatus k) {
    final scheme = Theme.of(context).colorScheme;
    final pending = _pendingDeleteHashes.contains(k.keyHash);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        StatusPill(
            label: context.tr('adminRisk.keyStatus_${k.status}'),
            tone: apiKeyTone(k.status),
            dense: true),
        const SizedBox(width: 8),
        Expanded(
          child: Text(k.masked.isEmpty ? '-' : k.masked,
              style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  decoration:
                      pending ? TextDecoration.lineThrough : null,
                  color: pending ? scheme.onSurfaceVariant : null),
              overflow: TextOverflow.ellipsis),
        ),
        if (k.keyHash.isNotEmpty)
          IconButton(
            icon: Icon(pending ? Icons.undo : Icons.delete_outline, size: 18),
            tooltip: pending
                ? context.tr('adminRisk.undoDeleteApiKey')
                : context.tr('adminRisk.deleteApiKey'),
            onPressed: () => setState(() {
              if (pending) {
                _pendingDeleteHashes.remove(k.keyHash);
              } else {
                _pendingDeleteHashes.add(k.keyHash);
              }
            }),
          ),
      ]),
    );
  }

  Widget _testedKeyRow(BuildContext context, ContentModerationApiKeyStatus k) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        StatusPill(
            label: context.tr('adminRisk.keyStatus_${k.status}'),
            tone: apiKeyTone(k.status),
            dense: true),
        const SizedBox(width: 8),
        Expanded(
          child: Text(k.masked.isEmpty ? '-' : k.masked,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              overflow: TextOverflow.ellipsis),
        ),
        if (k.lastLatencyMs > 0)
          Text('${k.lastLatencyMs}ms',
              style: Theme.of(context).textTheme.labelSmall),
      ]),
    );
  }

  Widget _auditResult(BuildContext context, ModerationTestAuditResult r) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: (r.flagged ? scheme.error : Colors.green)
            .withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              r.flagged
                  ? context.tr('adminRisk.auditFlagged')
                  : context.tr('adminRisk.auditPassed'),
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: r.flagged ? scheme.error : Colors.green)),
          const SizedBox(height: 4),
          Text(
              '${context.tr('adminRisk.auditComposite')} ${pct(r.compositeScore)}'
              '${r.highestCategory.isNotEmpty ? ' · ${r.highestCategory} ${pct(r.highestScore)}' : ''}',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  List<Widget> _scopeSection(BuildContext context, List<AdminGroup> groups) {
    final q = _groupSearch.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? groups
        : groups
            .where((g) =>
                g.name.toLowerCase().contains(q) ||
                g.platform.toLowerCase().contains(q))
            .toList();
    return [
      Row(children: [
        ChoiceChip(
          label: Text(context.tr('adminRisk.allGroups')),
          selected: _allGroups,
          onSelected: (_) => setState(() => _allGroups = true),
        ),
        const SizedBox(width: 6),
        ChoiceChip(
          label: Text(context.tr('adminRisk.selectedGroups')),
          selected: !_allGroups,
          onSelected: (_) => setState(() => _allGroups = false),
        ),
      ]),
      if (!_allGroups) ...[
        const SizedBox(height: 8),
        TextField(
          controller: _groupSearch,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: context.tr('adminRisk.searchGroups'),
            prefixIcon: const Icon(Icons.search, size: 18),
            isDense: true,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final g in filtered)
                  CheckboxListTile(
                    value: _groupIds.contains(g.id),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _groupIds.add(g.id);
                      } else {
                        _groupIds.remove(g.id);
                      }
                    }),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(g.name),
                    subtitle: Text(g.platform),
                  ),
              ],
            ),
          ),
        ),
      ],
      const Divider(height: 20),
      Text(context.tr('adminRisk.modelFilter'),
          style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 6),
      for (final type in kModelFilterTypes)
        RadioListTile<String>(
          value: type,
          // ignore: deprecated_member_use
          groupValue: _modelFilterType,
          // ignore: deprecated_member_use
          onChanged: (v) => setState(() => _modelFilterType = v ?? 'all'),
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(context.tr('adminRisk.modelFilter_$type')),
          subtitle: Text(context.tr('adminRisk.modelFilter_${type}_desc')),
        ),
      if (_modelFilterType != 'all') ...[
        const SizedBox(height: 6),
        TextField(
          controller: _modelFilterText,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: context.tr('adminRisk.modelFilterModels'),
            hintText: context.tr('adminRisk.modelFilterModelsHint'),
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        ),
      ],
    ];
  }

  List<Widget> _thresholdsSection(BuildContext context) {
    return [
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: () => setState(() {
            for (final cat in kRiskThresholdDefaults.keys) {
              _thresholds[cat]?.text = _trimNum(kRiskThresholdDefaults[cat] ?? 0);
            }
          }),
          icon: const Icon(Icons.refresh, size: 16),
          label: Text(context.tr('adminRisk.resetThresholds')),
        ),
      ),
      for (final cat in kRiskThresholdDefaults.keys)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(
              child: Text(cat,
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
            SizedBox(
              width: 96,
              child: TextField(
                controller: _thresholds[cat],
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  suffixText: '%',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
          ]),
        ),
    ];
  }

  List<Widget> _keywordsSection(BuildContext context) {
    return [
      Text(context.tr('adminRisk.keywordBlockingMode'),
          style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 6),
      for (final mode in kKeywordBlockingModes)
        RadioListTile<String>(
          value: mode,
          // ignore: deprecated_member_use
          groupValue: _keywordMode,
          // ignore: deprecated_member_use
          onChanged: (v) => setState(() => _keywordMode = v ?? 'keyword_and_api'),
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(context.tr('adminRisk.keywordMode_$mode')),
          subtitle: Text(context.tr('adminRisk.keywordMode_${mode}_desc')),
        ),
      const SizedBox(height: 8),
      TextField(
        controller: _blockedKeywords,
        maxLines: 6,
        enabled: _keywordMode != 'api_only',
        decoration: InputDecoration(
          labelText: context.tr('adminRisk.blockedKeywords'),
          hintText: context.tr('adminRisk.blockedKeywordsPlaceholder'),
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      ),
    ];
  }

  // ---------- 通用控件 ----------

  Widget _section(BuildContext context, String titleKey, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr(titleKey),
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _text(TextEditingController c, String labelKey, {bool number = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: c,
        keyboardType:
            number ? const TextInputType.numberWithOptions(decimal: true) : null,
        decoration: InputDecoration(
          labelText: context.tr(labelKey),
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _dropdown(BuildContext context, String labelKey, String value,
      List<String> options, ValueChanged<String> onChanged,
      {required String Function(String) labelOf}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: context.tr(labelKey),
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final o in options)
            DropdownMenuItem(value: o, child: Text(labelOf(o))),
        ],
        onChanged: (v) => onChanged(v ?? value),
      ),
    );
  }

  // ---------- 测试 / 保存 ----------

  List<String> _parseLines(String text) {
    final seen = <String>{};
    final out = <String>[];
    for (final line in text.split('\n')) {
      final t = line.trim();
      if (t.isEmpty || !seen.add(t)) continue;
      out.add(t);
    }
    return out;
  }

  Future<void> _runTest() async {
    setState(() => _testing = true);
    try {
      final keys = _parseLines(_apiKeysText.text);
      final res = await ref.read(adminRiskControlApiProvider).testApiKeys(
            apiKeys: keys,
            baseUrl: _baseUrl.text.trim(),
            model: _model.text.trim(),
            timeoutMs: int.tryParse(_timeoutMs.text.trim()),
            prompt: _testPrompt.text.trim(),
          );
      setState(() {
        _testedStatuses = res.items;
        _testAudit = res.auditResult;
      });
    } catch (e) {
      if (mounted) showAppToast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    final modelFilterModels =
        _modelFilterType == 'all' ? <String>[] : _parseLines(_modelFilterText.text);
    if (_modelFilterType != 'all' && modelFilterModels.isEmpty) {
      showAppToast(context, context.tr('adminRisk.modelFilterModelsRequired'),
          error: true);
      return;
    }
    final keys = _parseLines(_apiKeysText.text);
    if (!_clearApiKey && _apiKeysMode == 'replace' && keys.isEmpty) {
      showAppToast(context, context.tr('adminRisk.apiKeysReplaceNoInput'),
          error: true);
      return;
    }
    // 阈值:百分比 → 0-1 分数(4 位小数)
    final thresholds = <String, num>{};
    for (final cat in kRiskThresholdDefaults.keys) {
      final p = num.tryParse(_thresholds[cat]?.text.trim() ?? '') ?? 0;
      final clamped = p.clamp(0, 100).toDouble();
      thresholds[cat] = double.parse((clamped / 100).toStringAsFixed(4));
    }
    final nonHit = (int.tryParse(_nonHitRetention.text.trim()) ?? 3).clamp(1, 3);
    final payload = <String, dynamic>{
      'enabled': _enabled,
      'mode': _mode,
      'base_url': _baseUrl.text.trim(),
      'model': _model.text.trim(),
      'timeout_ms': int.tryParse(_timeoutMs.text.trim()) ?? 3000,
      'retry_count': int.tryParse(_retryCount.text.trim()) ?? 0,
      'sample_rate': num.tryParse(_sampleRate.text.trim()) ?? 0,
      'all_groups': _allGroups,
      'group_ids': _allGroups ? <int>[] : _groupIds.toList(),
      'record_non_hits': _recordNonHits,
      'clear_api_key': _clearApiKey,
      'worker_count': int.tryParse(_workerCount.text.trim()) ?? 4,
      'queue_size': int.tryParse(_queueSize.text.trim()) ?? 32768,
      'block_status': int.tryParse(_blockStatus.text.trim()) ?? 403,
      'block_message': _blockMessage.text.trim(),
      'email_on_hit': _emailOnHit,
      'auto_ban_enabled': _autoBan,
      'ban_threshold': int.tryParse(_banThreshold.text.trim()) ?? 10,
      'violation_window_hours': int.tryParse(_violationWindow.text.trim()) ?? 720,
      'hit_retention_days': int.tryParse(_hitRetention.text.trim()) ?? 180,
      'non_hit_retention_days': nonHit,
      'pre_hash_check_enabled': _preHashCheck,
      'thresholds': thresholds,
      'blocked_keywords': _parseLines(_blockedKeywords.text),
      'keyword_blocking_mode': _keywordMode,
      'model_filter': {'type': _modelFilterType, 'models': modelFilterModels},
    };
    if (keys.isNotEmpty) {
      payload['api_keys'] = keys;
      payload['api_keys_mode'] = _apiKeysMode;
      payload['clear_api_key'] = false;
    }
    if (!(payload['clear_api_key'] as bool) &&
        _apiKeysMode != 'replace' &&
        _pendingDeleteHashes.isNotEmpty) {
      payload['delete_api_key_hashes'] = _pendingDeleteHashes.toList();
    }
    setState(() => _saving = true);
    try {
      await ref.read(adminRiskControlApiProvider).updateConfig(payload);
      ref.invalidate(riskControlConfigProvider);
      ref.invalidate(riskControlStatusProvider);
      if (mounted) {
        showAppToast(context, context.tr('adminRisk.saved'));
        context.pop();
      }
    } catch (e) {
      if (mounted) showAppToast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
