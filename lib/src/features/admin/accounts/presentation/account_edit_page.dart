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
import '../data/account_platform_options.dart';
import '../data/account_quota.dart';
import '../data/admin_accounts_api.dart';
import '../providers/admin_accounts_providers.dart';
import '../../settings/providers/admin_settings_providers.dart';
import 'sections/custom_error_codes_section.dart';
import 'sections/model_restriction_section.dart';
import 'sections/openai_section.dart';
import 'sections/platform_toggle_sections.dart';
import 'sections/pool_mode_section.dart';
import 'sections/quota_advanced_section.dart';
import 'sections/quota_limit_section.dart';
import 'sections/temp_unschedulable_section.dart';

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
  QuotaLimitValue _quota = QuotaLimitValue();
  AdvancedQuotaValue _advQuota = AdvancedQuotaValue();
  OpenAiOptions _openai = OpenAiOptions();
  AnthropicApikeyOptions _anthropic = AnthropicApikeyOptions();
  AntigravityOptions _antigravity = AntigravityOptions();
  TempUnschedValue _tempUnsched = TempUnschedValue();
  bool _interceptWarmup = false;
  bool _hadCodexCliOnly = false;
  String? _credError;

  // 编辑态保存所需的原始 credentials/credentialsStatus/extra(用于合并)。
  Map<String, dynamic> _credentials = const {};
  Map<String, bool> _credentialsStatus = const {};
  Map<String, dynamic> _extra = const {};

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

  /// 配额控制(总/日/周):apikey / bedrock。
  bool get _showQuota => _isApiKey || _isBedrock;

  /// 高级配额(窗口费用/会话/RPM/TLS/...):Anthropic OAuth / setup-token。
  bool get _showAdvancedQuota =>
      _platform == 'anthropic' && (_type == 'oauth' || _type == 'setup-token');

  /// OpenAI 平台开关:openai oauth / apikey。
  bool get _showOpenAi =>
      _platform == 'openai' && (_type == 'oauth' || _isApiKey);

  /// Anthropic API Key 开关。
  bool get _showAnthropicApikey => _platform == 'anthropic' && _isApiKey;

  /// Antigravity 开关。
  bool get _showAntigravity => _isAntigravity;

  /// 拦截预热请求:anthropic / antigravity。
  bool get _showInterceptWarmup =>
      _platform == 'anthropic' || _isAntigravity;

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
    _extra = a.extra;
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

    _quota = QuotaLimitValue.fromAccount(a);
    _advQuota = AdvancedQuotaValue.fromAccount(a);
    _openai = OpenAiOptions.fromAccount(a);
    _anthropic = AnthropicApikeyOptions.fromAccount(a);
    _antigravity = AntigravityOptions.fromAccount(a);
    _tempUnsched = TempUnschedValue.fromCredentials(a.credentials);
    _interceptWarmup = a.credentials['intercept_warmup_requests'] == true;
    _hadCodexCliOnly = a.extra['codex_cli_only'] == true;
  }

  Widget _form(BuildContext context) {
    final groupsAsync = ref.watch(adminGroupsAllProvider);
    final proxiesAsync = ref.watch(adminProxiesAllProvider);
    // 全局「账号配额通知」开关:关闭时不显示通知配置(对照 web)。
    final notifyGlobal = ref.watch(adminSettingsProvider).maybeWhen(
          data: (m) => m['account_quota_notify_enabled'] == true,
          orElse: () => false,
        );
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

          // ===== 配额控制(总/日/周) =====
          if (_showQuota) ...[
            const SizedBox(height: 16),
            SectionHeader(title: context.tr('adminAccounts.sec.quota')),
            QuotaLimitSection(
              key: ValueKey('quota-$_type'),
              value: _quota,
              enabled: !_saving,
              notifyGlobalEnabled: notifyGlobal,
              onChanged: (v) => _quota = v,
            ),
          ],

          // ===== 高级配额(Anthropic OAuth/setup-token) =====
          if (_showAdvancedQuota) ...[
            const SizedBox(height: 16),
            SectionHeader(title: context.tr('adminAccounts.sec.quota')),
            ref.watch(adminTlsProfilesProvider).maybeWhen(
                  data: (profiles) => QuotaAdvancedSection(
                    key: ValueKey('adv-$_type'),
                    value: _advQuota,
                    enabled: !_saving,
                    tlsProfiles: profiles,
                    onChanged: (v) => _advQuota = v,
                  ),
                  orElse: () => QuotaAdvancedSection(
                    key: ValueKey('adv-$_type'),
                    value: _advQuota,
                    enabled: !_saving,
                    onChanged: (v) => _advQuota = v,
                  ),
                ),
          ],

          // ===== OpenAI 平台开关 =====
          if (_showOpenAi) ...[
            const SizedBox(height: 16),
            SectionHeader(title: 'OpenAI'),
            OpenAiSection(
              key: ValueKey('openai-$_type'),
              type: _type,
              value: _openai,
              enabled: !_saving,
              onChanged: (v) => _openai = v,
            ),
          ],

          // ===== Anthropic API Key 开关 =====
          if (_showAnthropicApikey) ...[
            const SizedBox(height: 16),
            SectionHeader(title: 'Anthropic'),
            AnthropicApikeySection(
              key: const ValueKey('anthropic-apikey'),
              value: _anthropic,
              enabled: !_saving,
              onChanged: (v) => _anthropic = v,
            ),
          ],

          // ===== Antigravity 开关 =====
          if (_showAntigravity) ...[
            const SizedBox(height: 16),
            SectionHeader(title: 'Antigravity'),
            AntigravitySection(
              key: const ValueKey('antigravity'),
              value: _antigravity,
              enabled: !_saving,
              onChanged: (v) => _antigravity = v,
            ),
          ],

          // ===== 拦截预热请求 =====
          if (_showInterceptWarmup)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr('adminAccounts.interceptWarmup')),
              subtitle: Text(context.tr('adminAccounts.interceptWarmupHint')),
              value: _interceptWarmup,
              onChanged:
                  _saving ? null : (v) => setState(() => _interceptWarmup = v),
            ),

          // ===== 临时不可调度规则(所有类型) =====
          const SizedBox(height: 16),
          SectionHeader(title: context.tr('adminAccounts.tempUnsched.title')),
          TempUnschedulableSection(
            key: ValueKey('tempunsched-$_type'),
            value: _tempUnsched,
            enabled: !_saving,
            onChanged: (v) => _tempUnsched = v,
          ),

          // ===== 调度与归属 =====
          const SizedBox(height: 16),
          SectionHeader(title: context.tr('adminAccounts.sec.scheduling')),
          const SizedBox(height: 4),
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
  /// 返回 null 表示校验失败([_credError] 已设),调用方应中止保存。
  Map<String, dynamic>? _buildCredentials() {
    _credError = null;
    final creds = <String, dynamic>{...(widget.isEdit ? _credentials : {})};

    if (_showApiKeyCreds) {
      final base = _baseUrl.text.trim();
      if (base.isNotEmpty) creds['base_url'] = base;
      final key = _apiKey.text.trim();
      if (key.isNotEmpty) creds['api_key'] = key;
    }

    // OpenAI 开启自动透传时保留现有模型映射,不再编辑(对照 web)。
    final openaiPassthrough = _showOpenAi && _openai.passthrough;
    if ((_showModelRestriction || _isAntigravity) && !openaiPassthrough) {
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

    if (_showOpenAi) _openai.applyToCredentials(creds, _type);

    // 拦截预热请求(anthropic / antigravity)。
    if (_showInterceptWarmup) {
      if (_interceptWarmup) {
        creds['intercept_warmup_requests'] = true;
      } else if (widget.isEdit) {
        creds.remove('intercept_warmup_requests');
      }
    }

    // 临时不可调度规则(所有类型);开启但无有效规则则中止。
    if (!_tempUnsched.applyToCredentials(creds)) {
      _credError = context.tr('adminAccounts.tempUnsched.rulesInvalid');
      return null;
    }

    return creds;
  }

  /// 构建提交用的 extra:从原始 extra 展开,各区块改/删键后整体回传。
  /// 后端 update 会保留运行态键(model_rate_limits 等)。
  Map<String, dynamic>? _buildExtra() {
    final touches = _showQuota ||
        _showAdvancedQuota ||
        _showOpenAi ||
        _showAnthropicApikey ||
        _showAntigravity;
    if (!touches) return null;
    final extra = <String, dynamic>{...(widget.isEdit ? _extra : {})};
    if (_showQuota) _quota.applyToExtra(extra);
    if (_showAdvancedQuota) _advQuota.applyToExtra(extra);
    if (_showOpenAi) {
      _openai.applyToExtra(extra, _type, hadCodexCliOnly: _hadCodexCliOnly);
    }
    if (_showAnthropicApikey) {
      _anthropic.applyToExtra(extra, webSearchGlobal: true);
    }
    if (_showAntigravity) _antigravity.applyToExtra(extra);
    return extra;
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
      if (creds == null) {
        if (mounted) {
          showAppToast(context, _credError ?? context.tr('common.error'),
              error: true);
          setState(() => _saving = false);
        }
        return;
      }
      body['credentials'] = creds;
      final extra = _buildExtra();
      if (extra != null) body['extra'] = extra;

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
