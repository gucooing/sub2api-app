import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../i18n/app_localizations.dart';
import '../../../../shared/format/formatters.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/responsive.dart';
import '../../../../shared/widgets/section_header.dart';
import '../data/account_model_mapping.dart';
import '../data/admin_accounts_api.dart';
import '../providers/admin_accounts_providers.dart';
import 'sections/custom_error_codes_section.dart';
import 'sections/model_restriction_section.dart';
import 'sections/pool_mode_section.dart';

/// 账号 新增 / 编辑。
///
/// 表单按 `(平台 × 类型)` 装配不同区块——不同平台、不同账号类型展示不同设置项,
/// 严格对照 web `EditAccountModal` / `CreateAccountModal`。本阶段(Phase 1)覆盖:
/// 基本信息、凭据(apikey/upstream)、**模型限制(白名单/映射)**、**池模式**、
/// **自定义错误码**、调度归属、并发/优先级/倍率、过期。配额控制与各平台高级
/// 开关在后续阶段补齐。
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

  String _platform = 'anthropic';
  String _type = 'apikey';
  bool _active = true;
  final Set<int> _groupIds = {};
  int? _proxyId;
  DateTime? _expiresAt;

  // 复合区块的当前值(由各 section 通过 onChanged 回填)。
  ModelRestrictionValue _model = ModelRestrictionValue();
  PoolModeValue _pool = PoolModeValue();
  CustomErrorCodesValue _errorCodes = CustomErrorCodesValue();

  // 编辑态保存所需的原始 credentials/credentialsStatus(用于合并 + 判定已有密钥)。
  Map<String, dynamic> _credentials = const {};
  Map<String, bool> _credentialsStatus = const {};

  bool _initialized = false;
  bool _saving = false;

  // ===== 区块可见性(对照 web 矩阵) =====
  bool get _isApiKey => _type == 'apikey';
  bool get _isBedrock => _type == 'bedrock';
  bool get _isUpstream => _type == 'upstream';
  bool get _isAntigravity => _platform == 'antigravity';

  /// base_url + api_key 凭据输入(apikey / upstream)。
  bool get _showApiKeyCreds => _isApiKey || _isUpstream;

  /// 模型限制(白名单/映射):apikey(非 antigravity)/bedrock/service_account/openai-oauth。
  bool get _showModelRestriction =>
      !_isAntigravity &&
      (_isApiKey ||
          _isBedrock ||
          _type == 'service_account' ||
          (_platform == 'openai' && _type == 'oauth'));

  /// 池模式:apikey / bedrock。
  bool get _showPoolMode => _isApiKey || _isBedrock;

  /// 自定义错误码:apikey。
  bool get _showCustomErrorCodes => _isApiKey;

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
    _active = a.isActive;
    _proxyId = a.proxyId;
    _groupIds
      ..clear()
      ..addAll(a.groupIds);
    if (a.expiresAt != null && a.expiresAt! > 0) {
      _expiresAt =
          DateTime.fromMillisecondsSinceEpoch(a.expiresAt! * 1000).toLocal();
    }

    _credentials = a.credentials;
    _credentialsStatus = a.credentialsStatus;
    _baseUrl.text = (a.credentials['base_url'] as String?) ?? '';

    // 模型限制:antigravity 与其它平台都落在 credentials.model_mapping。
    _model = ModelRestrictionValue.fromMapping(
        a.credentials['model_mapping'] as Map<String, dynamic>?);
    if (_isAntigravity) _model.mode = ModelRestrictionMode.mapping;

    // 池模式。
    _pool = PoolModeValue(
      enabled: a.credentials['pool_mode'] == true,
      retryCount: (a.credentials['pool_mode_retry_count'] as num?)?.toInt() ??
          kDefaultPoolModeRetryCount,
      retryStatusCodesInput:
          formatPoolModeRetryStatusCodes(a.credentials['pool_mode_retry_status_codes']),
    );

    // 自定义错误码。
    final rawCodes = a.credentials['custom_error_codes'];
    _errorCodes = CustomErrorCodesValue(
      enabled: a.credentials['custom_error_codes_enabled'] == true,
      codes: rawCodes is List
          ? [for (final c in rawCodes) if (c is num) c.toInt()]
          : const [],
    );
  }

  Widget _form(BuildContext context) {
    final groupsAsync = ref.watch(adminGroupsAllProvider);
    final proxiesAsync = ref.watch(adminProxiesAllProvider);
    return ResponsiveCenter(
      maxWidth: 640,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // ===== 基本信息 =====
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

          // ===== 凭据(apikey / upstream) =====
          if (_showApiKeyCreds) ...[
            const SizedBox(height: 8),
            SectionHeader(title: context.tr('adminAccounts.sec.credentials')),
            _field(_baseUrl, 'adminAccounts.fBaseUrl', optional: true),
            _field(_apiKey, 'adminAccounts.fApiKey',
                optional: widget.isEdit,
                hint: widget.isEdit ? 'adminAccounts.fApiKeyEditHint' : null),
          ],

          // ===== 模型限制 =====
          if (_showModelRestriction || _isAntigravity) ...[
            const SizedBox(height: 8),
            SectionHeader(title: context.tr('adminAccounts.sec.model')),
            ModelRestrictionSection(
              key: ValueKey('model-$_platform-$_type'),
              platform: _platform,
              value: _model,
              enabled: !_saving,
              mappingOnly: _isAntigravity,
              onSyncUpstream: (_isAntigravity && widget.isEdit)
                  ? () => ref
                      .read(adminAccountsApiProvider)
                      .syncUpstreamModels(widget.accountId!)
                  : null,
              onChanged: (v) => _model = v,
            ),
          ],

          // ===== 池模式 =====
          if (_showPoolMode) ...[
            const SizedBox(height: 16),
            SectionHeader(title: context.tr('adminAccounts.sec.poolMode')),
            PoolModeSection(
              key: ValueKey('pool-$_type'),
              value: _pool,
              enabled: !_saving,
              onChanged: (v) => _pool = v,
            ),
          ],

          // ===== 自定义错误码 =====
          if (_showCustomErrorCodes) ...[
            const SizedBox(height: 16),
            SectionHeader(title: context.tr('adminAccounts.sec.errorCodes')),
            CustomErrorCodesSection(
              key: ValueKey('ec-$_type'),
              value: _errorCodes,
              enabled: !_saving,
              onChanged: (v) => _errorCodes = v,
            ),
          ],

          // ===== 调度与归属 =====
          const SizedBox(height: 16),
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
                    value: null,
                    child: Text(context.tr('adminAccounts.proxyNone'))),
                for (final p in ps)
                  DropdownMenuItem(value: p.id, child: Text(p.name)),
              ],
              onChanged: _saving ? null : (v) => setState(() => _proxyId = v),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _field(_concurrency, 'adminAccounts.concurrency',
                    number: true)),
            const SizedBox(width: 12),
            Expanded(
                child: _field(_priority, 'adminAccounts.priority',
                    number: true)),
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
          const SizedBox(height: 4),
          _expiresField(context),

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

  /// 构建提交用的 credentials:从原始(脱敏)凭据展开,改/删键后整体回传。
  /// 后端 `MergePreservingSensitiveCreds` 会保留未重发的敏感键(api_key/token)。
  Map<String, dynamic>? _buildCredentials() {
    // 仅这些区块会触碰 credentials;都不涉及则返回 null(不提交 credentials)。
    final touches = _showApiKeyCreds ||
        _showModelRestriction ||
        _isAntigravity ||
        _showPoolMode ||
        _showCustomErrorCodes;
    if (!touches) return null;

    final creds = <String, dynamic>{...(widget.isEdit ? _credentials : {})};

    if (_showApiKeyCreds) {
      final base = _baseUrl.text.trim();
      if (base.isNotEmpty) creds['base_url'] = base;
      final key = _apiKey.text.trim();
      if (key.isNotEmpty) creds['api_key'] = key;
    }

    if (_showModelRestriction || _isAntigravity) {
      final mm = _model.build();
      if (mm != null) {
        creds['model_mapping'] = mm;
      } else {
        creds.remove('model_mapping');
      }
    }

    if (_showPoolMode) {
      if (_pool.enabled) {
        creds['pool_mode'] = true;
        creds['pool_mode_retry_count'] =
            _pool.retryCount.clamp(0, kMaxPoolModeRetryCount);
        final codes = parsePoolModeRetryStatusCodes(_pool.retryStatusCodesInput);
        if (codes.isNotEmpty) {
          creds['pool_mode_retry_status_codes'] = codes;
        } else {
          creds.remove('pool_mode_retry_status_codes');
        }
      } else {
        creds
          ..remove('pool_mode')
          ..remove('pool_mode_retry_count')
          ..remove('pool_mode_retry_status_codes');
      }
    }

    if (_showCustomErrorCodes) {
      if (_errorCodes.enabled) {
        creds['custom_error_codes_enabled'] = true;
        creds['custom_error_codes'] = _errorCodes.codes;
      } else {
        creds
          ..remove('custom_error_codes_enabled')
          ..remove('custom_error_codes');
      }
    }

    return creds;
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      showAppToast(context, context.tr('adminAccounts.nameRequired'),
          error: true);
      return;
    }
    // 新建 apikey:必须填写密钥;编辑:留空保留已有。
    if (_isApiKey) {
      final hasExisting = widget.isEdit &&
          (_credentialsStatus['has_api_key'] ??
              _credentials.containsKey('api_key'));
      if (_apiKey.text.trim().isEmpty && !hasExisting) {
        showAppToast(context, context.tr('adminAccounts.apiKeyRequired'),
            error: true);
        return;
      }
    }

    setState(() => _saving = true);
    final api = ref.read(adminAccountsApiProvider);
    int? pInt(TextEditingController c) => int.tryParse(c.text.trim());
    double? pDbl(TextEditingController c) => double.tryParse(c.text.trim());
    final expiresEpoch =
        _expiresAt == null ? 0 : _expiresAt!.millisecondsSinceEpoch ~/ 1000;
    try {
      final lf = pInt(_loadFactor);
      final body = <String, dynamic>{
        'name': _name.text.trim(),
        'notes': _notes.text.trim(),
        'concurrency': pInt(_concurrency) ?? 1,
        'priority': pInt(_priority) ?? 0,
        'rate_multiplier': ?pDbl(_rate),
        // load_factor <= 0 / 空 → 0(后端约定清除)。
        'load_factor': (lf != null && lf > 0) ? lf : 0,
        'proxy_id': _proxyId ?? 0, // 0 = 清除代理
        'expires_at': expiresEpoch, // 0 = 不过期
        'group_ids': _groupIds.toList(),
      };
      final creds = _buildCredentials();
      if (creds != null) body['credentials'] = creds;

      if (widget.isEdit) {
        body['status'] = _active ? 'active' : 'inactive';
        await api.update(widget.accountId!, body);
      } else {
        body['platform'] = _platform;
        body['type'] = _type;
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
      {bool number = false,
      bool optional = false,
      String? hint,
      int lines = 1}) {
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
                value: e.key,
                child: Text(raw ? e.value : context.tr(e.value))),
        ],
        onChanged: _saving ? null : (v) => onChanged(v ?? value),
      ),
    );
  }
}
