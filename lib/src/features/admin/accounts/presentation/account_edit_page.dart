import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../i18n/app_localizations.dart';
import '../../../../shared/format/formatters.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/responsive.dart';
import '../../../../shared/widgets/section_header.dart';
import '../data/admin_accounts_api.dart';
import '../providers/admin_accounts_providers.dart';

/// 账号 新增 / 编辑(对照 web EditAccountModal / CreateAccountModal 的核心字段):
/// 基本信息 + 凭据(apikey/bedrock)+ 调度与归属(分组/代理)+ 配额控制(Anthropic OAuth)。
class AccountEditPage extends ConsumerStatefulWidget {
  const AccountEditPage({super.key, this.accountId});

  final int? accountId;
  bool get isEdit => accountId != null;

  @override
  ConsumerState<AccountEditPage> createState() => _AccountEditPageState();
}

class _AccountEditPageState extends ConsumerState<AccountEditPage> {
  final _name = TextEditingController();
  final _notes = TextEditingController();
  final _baseUrl = TextEditingController();
  final _apiKey = TextEditingController();
  final _concurrency = TextEditingController(text: '1');
  final _priority = TextEditingController(text: '0');
  final _rate = TextEditingController();
  final _loadFactor = TextEditingController();
  final _windowCost = TextEditingController();
  final _windowReserve = TextEditingController();
  final _maxSessions = TextEditingController();
  final _idleTimeout = TextEditingController();
  final _baseRpm = TextEditingController();

  String _platform = 'anthropic';
  String _type = 'apikey';
  bool _active = true;
  final Set<int> _groupIds = {};
  int? _proxyId;
  DateTime? _expiresAt;

  bool _initialized = false;
  bool _saving = false;

  bool get _isApiKeyType => _type == 'apikey' || _type == 'bedrock';
  bool get _showQuota =>
      _platform == 'anthropic' && (_type == 'oauth' || _type == 'setup-token');

  @override
  void dispose() {
    for (final c in [
      _name,
      _notes,
      _baseUrl,
      _apiKey,
      _concurrency,
      _priority,
      _rate,
      _loadFactor,
      _windowCost,
      _windowReserve,
      _maxSessions,
      _idleTimeout,
      _baseRpm,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = context.tr(
        widget.isEdit ? 'adminAccounts.editTitle' : 'adminAccounts.addTitle');
    if (!widget.isEdit) {
      return Scaffold(appBar: AppBar(title: Text(title)), body: _form(context));
    }
    final async = ref.watch(adminAccountDetailProvider(widget.accountId!));
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetryView(
          error: e,
          onRetry: () =>
              ref.invalidate(adminAccountDetailProvider(widget.accountId!)),
        ),
        data: (a) {
          if (!_initialized) {
            _initialized = true;
            _prefill(a);
          }
          return _form(context);
        },
      ),
    );
  }

  void _prefill(AdminAccount a) {
    _name.text = a.name;
    _notes.text = a.notes ?? '';
    _platform = a.platform.isEmpty ? 'anthropic' : a.platform;
    _type = a.type.isEmpty ? 'apikey' : a.type;
    _concurrency.text = '${a.concurrency}';
    _priority.text = '${a.priority}';
    _rate.text = a.rateMultiplier?.toString() ?? '';
    _loadFactor.text = a.loadFactor?.toString() ?? '';
    _windowCost.text = a.windowCostLimit?.toString() ?? '';
    _windowReserve.text = a.windowCostStickyReserve?.toString() ?? '';
    _maxSessions.text = a.maxSessions?.toString() ?? '';
    _idleTimeout.text = a.sessionIdleTimeoutMinutes?.toString() ?? '';
    _baseRpm.text = a.baseRpm?.toString() ?? '';
    _active = a.isActive;
    _proxyId = a.proxyId;
    _groupIds.addAll([]); // group_ids 来自详情时无 id 列表,保持空(展示按 groupNames)
    if (a.expiresAt != null && a.expiresAt! > 0) {
      _expiresAt =
          DateTime.fromMillisecondsSinceEpoch(a.expiresAt! * 1000).toLocal();
    }
  }

  Widget _form(BuildContext context) {
    final groupsAsync = ref.watch(adminGroupsAllProvider);
    final proxiesAsync = ref.watch(adminProxiesAllProvider);
    return ResponsiveCenter(
      maxWidth: 640,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SectionHeader(title: context.tr('adminAccounts.sec.basic')),
          _field(_name, 'adminAccounts.fName'),
          _field(_notes, 'adminAccounts.notes', optional: true, lines: 2),
          if (!widget.isEdit) ...[
            _dropdown('adminAccounts.platform', _platform, const {
              'anthropic': 'Anthropic',
              'openai': 'OpenAI',
              'gemini': 'Gemini',
              'antigravity': 'Antigravity',
            }, (v) => setState(() => _platform = v), raw: true),
            _dropdown('adminAccounts.type', _type, const {
              'apikey': 'adminAccounts.typeApikey',
              'bedrock': 'adminAccounts.typeBedrock',
            }, (v) => setState(() => _type = v)),
          ],
          if (widget.isEdit)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr('adminAccounts.statusActive')),
              value: _active,
              onChanged: _saving ? null : (v) => setState(() => _active = v),
            ),
          Row(children: [
            Expanded(
                child:
                    _field(_concurrency, 'adminAccounts.concurrency', number: true)),
            const SizedBox(width: 12),
            Expanded(
                child: _field(_priority, 'adminAccounts.priority', number: true)),
          ]),
          Row(children: [
            Expanded(
                child: _field(_rate, 'adminAccounts.rateMultiplier',
                    number: true, optional: true)),
            const SizedBox(width: 12),
            Expanded(
                child: _field(_loadFactor, 'adminAccounts.loadFactor',
                    number: true, optional: true)),
          ]),
          if (_isApiKeyType) ...[
            const SizedBox(height: 8),
            SectionHeader(title: context.tr('adminAccounts.sec.credentials')),
            _field(_baseUrl, 'adminAccounts.fBaseUrl', optional: true),
            _field(_apiKey, 'adminAccounts.fApiKey',
                optional: widget.isEdit,
                hint: widget.isEdit ? 'adminAccounts.fApiKeyEditHint' : null),
          ],
          const SizedBox(height: 8),
          SectionHeader(title: context.tr('adminAccounts.sec.scheduling')),
          Text(context.tr('adminAccounts.groups'),
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 6),
          groupsAsync.maybeWhen(
            data: (gs) => Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final g in gs)
                  FilterChip(
                    label: Text(g.name),
                    selected: _groupIds.contains(g.id),
                    onSelected: _saving
                        ? null
                        : (s) => setState(() =>
                            s ? _groupIds.add(g.id) : _groupIds.remove(g.id)),
                  ),
              ],
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),
          proxiesAsync.maybeWhen(
            data: (ps) => DropdownButtonFormField<int?>(
              initialValue: ps.any((p) => p.id == _proxyId) ? _proxyId : null,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: context.tr('adminAccounts.proxy'),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                    value: null, child: Text(context.tr('adminAccounts.proxyNone'))),
                for (final p in ps)
                  DropdownMenuItem(value: p.id, child: Text(p.name)),
              ],
              onChanged: _saving ? null : (v) => setState(() => _proxyId = v),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),
          _expiresField(context),
          if (_showQuota) ...[
            const SizedBox(height: 8),
            SectionHeader(title: context.tr('adminAccounts.sec.quota')),
            Row(children: [
              Expanded(
                  child: _field(_windowCost, 'adminAccounts.windowCostLimit',
                      number: true, optional: true)),
              const SizedBox(width: 12),
              Expanded(
                  child: _field(_windowReserve, 'adminAccounts.windowReserve',
                      number: true, optional: true)),
            ]),
            Row(children: [
              Expanded(
                  child: _field(_maxSessions, 'adminAccounts.maxSessions',
                      number: true, optional: true)),
              const SizedBox(width: 12),
              Expanded(
                  child: _field(_idleTimeout, 'adminAccounts.idleTimeout',
                      number: true, optional: true)),
            ]),
            _field(_baseRpm, 'adminAccounts.baseRpm',
                number: true, optional: true),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(context.tr('common.save')),
          ),
        ],
      ),
    );
  }

  Widget _expiresField(BuildContext context) {
    return InkWell(
      onTap: _saving
          ? null
          : () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: _expiresAt ?? now,
                firstDate: now.subtract(const Duration(days: 1)),
                lastDate: now.add(const Duration(days: 3650)),
              );
              if (picked != null) setState(() => _expiresAt = picked);
            },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: context.tr('adminAccounts.expiresAt'),
          isDense: true,
          border: const OutlineInputBorder(),
          suffixIcon: _expiresAt == null
              ? const Icon(Icons.calendar_today_outlined, size: 18)
              : IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: _saving
                      ? null
                      : () => setState(() => _expiresAt = null),
                ),
        ),
        child: Text(_expiresAt == null
            ? context.tr('adminAccounts.noExpiry')
            : formatDate(_expiresAt!)),
      ),
    );
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      showAppToast(context, context.tr('adminAccounts.nameRequired'),
          error: true);
      return;
    }
    setState(() => _saving = true);
    final api = ref.read(adminAccountsApiProvider);
    int? pInt(TextEditingController c) => int.tryParse(c.text.trim());
    double? pDbl(TextEditingController c) => double.tryParse(c.text.trim());
    final expiresEpoch =
        _expiresAt == null ? null : _expiresAt!.millisecondsSinceEpoch ~/ 1000;
    try {
      final body = <String, dynamic>{
        'name': _name.text.trim(),
        'notes': _notes.text.trim(),
        'concurrency': pInt(_concurrency) ?? 1,
        'priority': pInt(_priority) ?? 0,
        'rate_multiplier': ?pDbl(_rate),
        'load_factor': ?pDbl(_loadFactor),
        'proxy_id': _proxyId,
        'expires_at': expiresEpoch,
        if (_groupIds.isNotEmpty) 'group_ids': _groupIds.toList(),
        if (_showQuota) ...{
          'window_cost_limit': ?pDbl(_windowCost),
          'window_cost_sticky_reserve': ?pDbl(_windowReserve),
          'max_sessions': ?pInt(_maxSessions),
          'session_idle_timeout_minutes': ?pInt(_idleTimeout),
          'base_rpm': ?pInt(_baseRpm),
        },
      };
      if (widget.isEdit) {
        body['status'] = _active ? 'active' : 'inactive';
        if (_isApiKeyType && _apiKey.text.trim().isNotEmpty) {
          body['credentials'] = {'api_key': _apiKey.text.trim()};
        }
        if (_isApiKeyType && _baseUrl.text.trim().isNotEmpty) {
          body['base_url'] = _baseUrl.text.trim();
        }
        await api.update(widget.accountId!, body);
      } else {
        body['platform'] = _platform;
        body['type'] = _type;
        body['credentials'] = {'api_key': _apiKey.text.trim()};
        if (_baseUrl.text.trim().isNotEmpty) {
          body['base_url'] = _baseUrl.text.trim();
        }
        await api.create(body);
      }
      ref.invalidate(adminAccountsControllerProvider);
      if (widget.isEdit) {
        ref.invalidate(adminAccountDetailProvider(widget.accountId!));
      }
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

  Widget _field(TextEditingController c, String labelKey,
      {bool number = false, bool optional = false, String? hint, int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        enabled: !_saving,
        maxLines: lines,
        keyboardType: number ? TextInputType.number : null,
        decoration: InputDecoration(
          labelText: optional
              ? '${context.tr(labelKey)} (${context.tr('common.optional')})'
              : context.tr(labelKey),
          helperText: hint == null ? null : context.tr(hint),
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _dropdown(String labelKey, String value, Map<String, String> items,
      ValueChanged<String> onChanged,
      {bool raw = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: context.tr(labelKey),
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final e in items.entries)
            DropdownMenuItem(
                value: e.key, child: Text(raw ? e.value : context.tr(e.value))),
        ],
        onChanged: _saving ? null : (v) => onChanged(v ?? value),
      ),
    );
  }
}
