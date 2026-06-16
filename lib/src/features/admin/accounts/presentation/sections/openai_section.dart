import 'package:flutter/material.dart';

import '../../../../../i18n/app_localizations.dart';
import '../../../../../shared/widgets/pill_segmented.dart';
import '../../data/account_model_mapping.dart';
import '../../data/account_platform_options.dart';

/// OpenAI(oauth / apikey)平台开关区块。
class OpenAiSection extends StatefulWidget {
  const OpenAiSection({
    super.key,
    required this.type, // oauth / apikey
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String type;
  final OpenAiOptions value;
  final ValueChanged<OpenAiOptions> onChanged;
  final bool enabled;

  @override
  State<OpenAiSection> createState() => _OpenAiSectionState();
}

class _OpenAiSectionState extends State<OpenAiSection> {
  late OpenAiOptions _v;
  late List<_MapRow> _compact;
  final _p5h = TextEditingController();
  final _p7d = TextEditingController();

  bool get _isApiKey => widget.type == 'apikey';
  bool get _isOauth => widget.type == 'oauth';

  @override
  void initState() {
    super.initState();
    _v = widget.value;
    _compact = [for (final m in _v.compactMappings) _MapRow(m.from, m.to)];
    if (_v.autoPause5hThreshold != null) _p5h.text = '${_v.autoPause5hThreshold}';
    if (_v.autoPause7dThreshold != null) _p7d.text = '${_v.autoPause7dThreshold}';
  }

  @override
  void dispose() {
    _p5h.dispose();
    _p7d.dispose();
    for (final r in _compact) {
      r.dispose();
    }
    super.dispose();
  }

  void _syncCompact() {
    _v.compactMappings = [
      for (final r in _compact) ModelMappingEntry(from: r.from.text, to: r.to.text),
    ];
  }

  void _emit() {
    _syncCompact();
    widget.onChanged(_v);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _toggle(
          context.tr('adminAccounts.openai.passthrough'),
          context.tr('adminAccounts.openai.passthroughHint'),
          _v.passthrough,
          (b) => setState(() {
            _v.passthrough = b;
            _emit();
          }),
        ),
        const SizedBox(height: 12),
        _labeled(
          context.tr('adminAccounts.openai.wsMode'),
          context.tr('adminAccounts.openai.wsModeHint'),
          PillSegmented<String>(
            selected: _v.wsMode,
            onChanged: widget.enabled
                ? (m) => setState(() {
                      _v.wsMode = m;
                      _emit();
                    })
                : (_) {},
            options: [
              ('off', context.tr('adminAccounts.openai.wsOff')),
              ('ctx_pool', context.tr('adminAccounts.openai.wsCtxPool')),
              ('passthrough', context.tr('adminAccounts.openai.wsPassthrough')),
            ],
          ),
        ),
        if (_isApiKey) ...[
          const SizedBox(height: 12),
          _labeled(
            context.tr('adminAccounts.openai.responsesMode'),
            context.tr('adminAccounts.openai.responsesModeHint'),
            PillSegmented<String>(
              selected: _v.responsesMode,
              onChanged: widget.enabled && _v.textGenEnabled
                  ? (m) => setState(() {
                        _v.responsesMode = m;
                        _emit();
                      })
                  : (_) {},
              options: [
                ('auto', context.tr('adminAccounts.openai.respAuto')),
                ('force_responses', context.tr('adminAccounts.openai.respForce')),
                ('force_chat_completions',
                    context.tr('adminAccounts.openai.respChat')),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(context.tr('adminAccounts.openai.capabilities'),
              style: theme.textTheme.bodySmall),
          Row(children: [
            for (final cap in const ['chat_completions', 'embeddings'])
              Expanded(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _v.capabilities.contains(cap),
                  title: Text(
                      context.tr('adminAccounts.openai.cap.$cap'),
                      style: theme.textTheme.bodySmall),
                  onChanged: widget.enabled
                      ? (b) => setState(() {
                            if (b == true) {
                              _v.capabilities.add(cap);
                            } else if (_v.capabilities.length > 1) {
                              _v.capabilities.remove(cap);
                            }
                            if (!_v.textGenEnabled) _v.responsesMode = 'auto';
                            _emit();
                          })
                      : null,
                ),
              ),
          ]),
        ],
        if (_isOauth) ...[
          const SizedBox(height: 12),
          _toggle(
            context.tr('adminAccounts.openai.codexCliOnly'),
            context.tr('adminAccounts.openai.codexCliOnlyHint'),
            _v.codexCliOnly,
            (b) => setState(() {
              _v.codexCliOnly = b;
              _emit();
            }),
          ),
          if (_v.codexCliOnly)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 4),
              child: _toggle(
                context.tr('adminAccounts.openai.allowClaudeCode'),
                context.tr('adminAccounts.openai.allowClaudeCodeHint'),
                _v.allowClaudeCode,
                (b) => setState(() {
                  _v.allowClaudeCode = b;
                  _emit();
                }),
              ),
            ),
        ],
        const SizedBox(height: 12),
        _labeled(
          context.tr('adminAccounts.openai.compactMode'),
          context.tr('adminAccounts.openai.compactModeHint'),
          PillSegmented<String>(
            selected: _v.compactMode,
            onChanged: widget.enabled
                ? (m) => setState(() {
                      _v.compactMode = m;
                      _emit();
                    })
                : (_) {},
            options: [
              ('auto', context.tr('adminAccounts.openai.compactAuto')),
              ('force_on', context.tr('adminAccounts.openai.compactOn')),
              ('force_off', context.tr('adminAccounts.openai.compactOff')),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(context.tr('adminAccounts.openai.compactMapping'),
            style: theme.textTheme.bodySmall),
        for (var i = 0; i < _compact.length; i++) _compactRow(theme, i),
        OutlinedButton.icon(
          onPressed: widget.enabled
              ? () => setState(() {
                    _compact.add(_MapRow('', ''));
                    _emit();
                  })
              : null,
          icon: const Icon(Icons.add, size: 18),
          label: Text(context.tr('adminAccounts.model.addMapping')),
        ),
        const SizedBox(height: 12),
        _labeled(
          context.tr('adminAccounts.openai.imageBridge'),
          context.tr('adminAccounts.openai.imageBridgeHint'),
          PillSegmented<String>(
            selected: _v.imageBridge,
            onChanged: widget.enabled
                ? (m) => setState(() {
                      _v.imageBridge = m;
                      _emit();
                    })
                : (_) {},
            options: [
              ('inherit', context.tr('adminAccounts.openai.bridgeInherit')),
              ('enabled', context.tr('adminAccounts.openai.bridgeEnabled')),
              ('disabled', context.tr('adminAccounts.openai.bridgeDisabled')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _autoPause(theme),
      ],
    );
  }

  Widget _autoPause(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _toggle(
          context.tr('adminAccounts.openai.autoPause5hDisabled'),
          context.tr('adminAccounts.openai.autoPauseDisabledHint'),
          _v.autoPause5hDisabled,
          (b) => setState(() {
            _v.autoPause5hDisabled = b;
            _emit();
          }),
        ),
        TextField(
          controller: _p5h,
          enabled: widget.enabled && !_v.autoPause5hDisabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: context.tr('adminAccounts.openai.autoPause5hThreshold'),
            suffixText: '%',
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          onChanged: (t) {
            _v.autoPause5hThreshold = num.tryParse(t.trim());
            _emit();
          },
        ),
        const SizedBox(height: 12),
        _toggle(
          context.tr('adminAccounts.openai.autoPause7dDisabled'),
          context.tr('adminAccounts.openai.autoPauseDisabledHint'),
          _v.autoPause7dDisabled,
          (b) => setState(() {
            _v.autoPause7dDisabled = b;
            _emit();
          }),
        ),
        TextField(
          controller: _p7d,
          enabled: widget.enabled && !_v.autoPause7dDisabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: context.tr('adminAccounts.openai.autoPause7dThreshold'),
            suffixText: '%',
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          onChanged: (t) {
            _v.autoPause7dThreshold = num.tryParse(t.trim());
            _emit();
          },
        ),
      ],
    );
  }

  Widget _compactRow(ThemeData theme, int i) {
    final row = _compact[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: row.from,
            enabled: widget.enabled,
            decoration: InputDecoration(
              isDense: true,
              border: const OutlineInputBorder(),
              hintText: context.tr('adminAccounts.model.requestModel'),
            ),
            onChanged: (_) => _emit(),
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
            ),
            onChanged: (_) => _emit(),
          ),
        ),
        IconButton(
          onPressed: widget.enabled
              ? () => setState(() {
                    _compact.removeAt(i).dispose();
                    _emit();
                  })
              : null,
          icon: Icon(Icons.delete_outline,
              size: 20, color: theme.colorScheme.error),
        ),
      ]),
    );
  }

  Widget _toggle(
      String title, String hint, bool value, ValueChanged<bool> onChanged) {
    final theme = Theme.of(context);
    return Row(children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            Text(hint,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
      Switch(value: value, onChanged: widget.enabled ? onChanged : null),
    ]);
  }

  Widget _labeled(String title, String hint, Widget child) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        Text(hint,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        Align(alignment: Alignment.centerLeft, child: child),
      ],
    );
  }
}

class _MapRow {
  _MapRow(String f, String t)
      : from = TextEditingController(text: f),
        to = TextEditingController(text: t);
  final TextEditingController from;
  final TextEditingController to;
  void dispose() {
    from.dispose();
    to.dispose();
  }
}
