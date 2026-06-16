import 'package:flutter/material.dart';

import '../../../../../i18n/app_localizations.dart';
import '../../../../../shared/widgets/pill_segmented.dart';
import '../../data/account_quota.dart';

/// 高级配额控制(Anthropic OAuth / setup-token):窗口费用 / 会话 / RPM / UMQ /
/// TLS 指纹 / 会话ID掩码 / 缓存TTL / 自定义 BaseURL。
class QuotaAdvancedSection extends StatefulWidget {
  const QuotaAdvancedSection({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.tlsProfiles = const [],
  });

  final AdvancedQuotaValue value;
  final ValueChanged<AdvancedQuotaValue> onChanged;
  final bool enabled;
  final List<({int id, String name})> tlsProfiles;

  @override
  State<QuotaAdvancedSection> createState() => _QuotaAdvancedSectionState();
}

class _QuotaAdvancedSectionState extends State<QuotaAdvancedSection> {
  late AdvancedQuotaValue _v;
  final _windowLimit = TextEditingController();
  final _windowReserve = TextEditingController();
  final _maxSessions = TextEditingController();
  final _idleTimeout = TextEditingController();
  final _baseRpm = TextEditingController();
  final _stickyBuffer = TextEditingController();
  final _customBaseUrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _v = widget.value;
    _windowLimit.text = _t(_v.windowCostLimit);
    _windowReserve.text = _t(_v.windowCostStickyReserve);
    _maxSessions.text = _t(_v.maxSessions);
    _idleTimeout.text = _t(_v.sessionIdleTimeout);
    _baseRpm.text = _t(_v.baseRpm);
    _stickyBuffer.text = _t(_v.rpmStickyBuffer);
    _customBaseUrl.text = _v.customBaseUrl;
  }

  static String _t(num? v) => v == null ? '' : '$v';

  @override
  void dispose() {
    for (final c in [
      _windowLimit,
      _windowReserve,
      _maxSessions,
      _idleTimeout,
      _baseRpm,
      _stickyBuffer,
      _customBaseUrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _emit() => widget.onChanged(_v);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _windowCostCard(),
        const SizedBox(height: 12),
        _sessionCard(),
        const SizedBox(height: 12),
        _rpmCard(),
        const SizedBox(height: 12),
        _tlsCard(),
        const SizedBox(height: 12),
        _sessionMaskingCard(),
        const SizedBox(height: 12),
        _cacheTtlCard(),
        const SizedBox(height: 12),
        _customBaseUrlCard(),
      ],
    );
  }

  Widget _card({
    required String title,
    String? hint,
    required bool value,
    required ValueChanged<bool> onToggle,
    Widget? body,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  if (hint != null)
                    Text(hint,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: widget.enabled ? onToggle : null,
            ),
          ]),
          if (value && body != null) ...[const SizedBox(height: 12), body],
        ],
      ),
    );
  }

  InputDecoration _dec(String hint, {String? prefix, String? suffix}) =>
      InputDecoration(
        isDense: true,
        border: const OutlineInputBorder(),
        hintText: hint,
        prefixText: prefix,
        suffixText: suffix,
      );

  Widget _windowCostCard() => _card(
        title: context.tr('adminAccounts.adv.windowCost'),
        hint: context.tr('adminAccounts.adv.windowCostHint'),
        value: _v.windowCostEnabled,
        onToggle: (v) {
          setState(() => _v.windowCostEnabled = v);
          _emit();
        },
        body: Row(children: [
          Expanded(
            child: TextField(
              controller: _windowLimit,
              enabled: widget.enabled,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: _dec(context.tr('adminAccounts.adv.windowLimit'),
                  prefix: '\$ '),
              onChanged: (t) {
                _v.windowCostLimit = num.tryParse(t.trim());
                _emit();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _windowReserve,
              enabled: widget.enabled,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: _dec(context.tr('adminAccounts.adv.windowReserve'),
                  prefix: '\$ '),
              onChanged: (t) {
                _v.windowCostStickyReserve = num.tryParse(t.trim());
                _emit();
              },
            ),
          ),
        ]),
      );

  Widget _sessionCard() => _card(
        title: context.tr('adminAccounts.adv.sessionLimit'),
        hint: context.tr('adminAccounts.adv.sessionLimitHint'),
        value: _v.sessionLimitEnabled,
        onToggle: (v) {
          setState(() => _v.sessionLimitEnabled = v);
          _emit();
        },
        body: Row(children: [
          Expanded(
            child: TextField(
              controller: _maxSessions,
              enabled: widget.enabled,
              keyboardType: TextInputType.number,
              decoration: _dec(context.tr('adminAccounts.adv.maxSessions')),
              onChanged: (t) {
                _v.maxSessions = int.tryParse(t.trim());
                _emit();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _idleTimeout,
              enabled: widget.enabled,
              keyboardType: TextInputType.number,
              decoration: _dec(context.tr('adminAccounts.adv.idleTimeout'),
                  suffix: context.tr('adminAccounts.adv.minutes')),
              onChanged: (t) {
                _v.sessionIdleTimeout = int.tryParse(t.trim());
                _emit();
              },
            ),
          ),
        ]),
      );

  Widget _rpmCard() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr('adminAccounts.adv.rpm'),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  Text(context.tr('adminAccounts.adv.rpmHint'),
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            Switch(
              value: _v.rpmEnabled,
              onChanged: widget.enabled
                  ? (v) {
                      setState(() => _v.rpmEnabled = v);
                      _emit();
                    }
                  : null,
            ),
          ]),
          if (_v.rpmEnabled) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _baseRpm,
              enabled: widget.enabled,
              keyboardType: TextInputType.number,
              decoration: _dec(context.tr('adminAccounts.adv.baseRpm')),
              onChanged: (t) {
                _v.baseRpm = int.tryParse(t.trim());
                _emit();
              },
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: PillSegmented<String>(
                selected: _v.rpmStrategy,
                onChanged: widget.enabled
                    ? (s) {
                        setState(() => _v.rpmStrategy = s);
                        _emit();
                      }
                    : (_) {},
                options: [
                  ('tiered', context.tr('adminAccounts.adv.rpmTiered')),
                  ('sticky_exempt',
                      context.tr('adminAccounts.adv.rpmStickyExempt')),
                ],
              ),
            ),
            if (_v.rpmStrategy == 'tiered') ...[
              const SizedBox(height: 10),
              TextField(
                controller: _stickyBuffer,
                enabled: widget.enabled,
                keyboardType: TextInputType.number,
                decoration: _dec(context.tr('adminAccounts.adv.stickyBuffer')),
                onChanged: (t) {
                  _v.rpmStickyBuffer = int.tryParse(t.trim());
                  _emit();
                },
              ),
            ],
          ],
          // 用户消息限速模式(独立于 RPM 开关,始终可见)。
          const SizedBox(height: 12),
          Text(context.tr('adminAccounts.adv.umq'),
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: PillSegmented<String>(
              selected: _v.userMsgQueueMode,
              onChanged: widget.enabled
                  ? (m) {
                      setState(() => _v.userMsgQueueMode = m);
                      _emit();
                    }
                  : (_) {},
              options: [
                ('', context.tr('adminAccounts.adv.umqOff')),
                ('throttle', context.tr('adminAccounts.adv.umqThrottle')),
                ('serialize', context.tr('adminAccounts.adv.umqSerialize')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tlsCard() => _card(
        title: context.tr('adminAccounts.adv.tls'),
        hint: context.tr('adminAccounts.adv.tlsHint'),
        value: _v.tlsEnabled,
        onToggle: (v) {
          setState(() => _v.tlsEnabled = v);
          _emit();
        },
        body: DropdownButtonFormField<int?>(
          initialValue: _v.tlsProfileId,
          isExpanded: true,
          decoration: _dec(context.tr('adminAccounts.adv.tlsProfile')),
          items: [
            DropdownMenuItem(
                value: null, child: Text(context.tr('adminAccounts.adv.tlsDefault'))),
            if (widget.tlsProfiles.isNotEmpty)
              DropdownMenuItem(
                  value: -1, child: Text(context.tr('adminAccounts.adv.tlsRandom'))),
            for (final p in widget.tlsProfiles)
              DropdownMenuItem(value: p.id, child: Text(p.name)),
          ],
          onChanged: widget.enabled
              ? (v) {
                  setState(() => _v.tlsProfileId = v);
                  _emit();
                }
              : null,
        ),
      );

  Widget _sessionMaskingCard() => _card(
        title: context.tr('adminAccounts.adv.sessionMasking'),
        hint: context.tr('adminAccounts.adv.sessionMaskingHint'),
        value: _v.sessionIdMasking,
        onToggle: (v) {
          setState(() => _v.sessionIdMasking = v);
          _emit();
        },
      );

  Widget _cacheTtlCard() => _card(
        title: context.tr('adminAccounts.adv.cacheTtl'),
        hint: context.tr('adminAccounts.adv.cacheTtlHint'),
        value: _v.cacheTtlEnabled,
        onToggle: (v) {
          setState(() => _v.cacheTtlEnabled = v);
          _emit();
        },
        body: Align(
          alignment: Alignment.centerLeft,
          child: PillSegmented<String>(
            selected: _v.cacheTtlTarget,
            onChanged: widget.enabled
                ? (t) {
                    setState(() => _v.cacheTtlTarget = t);
                    _emit();
                  }
                : (_) {},
            options: const [('5m', '5m'), ('1h', '1h')],
          ),
        ),
      );

  Widget _customBaseUrlCard() => _card(
        title: context.tr('adminAccounts.adv.customBaseUrl'),
        hint: context.tr('adminAccounts.adv.customBaseUrlHint'),
        value: _v.customBaseUrlEnabled,
        onToggle: (v) {
          setState(() => _v.customBaseUrlEnabled = v);
          _emit();
        },
        body: TextField(
          controller: _customBaseUrl,
          enabled: widget.enabled,
          decoration: _dec('https://...'),
          onChanged: (t) {
            _v.customBaseUrl = t;
            _emit();
          },
        ),
      );
}
