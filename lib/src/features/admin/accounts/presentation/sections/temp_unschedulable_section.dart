import 'package:flutter/material.dart';

import '../../../../../i18n/app_localizations.dart';
import '../../data/account_platform_options.dart';

/// 预设规则。
class _Preset {
  const _Preset(this.label, this.code, this.keywords, this.minutes);
  final String label;
  final int code;
  final String keywords;
  final int minutes;
}

const List<_Preset> _presets = [
  _Preset('overload', 529, 'overloaded, too many', 60),
  _Preset('rateLimit', 429, 'rate limit, too many requests', 10),
  _Preset('unavailable', 503, 'unavailable, maintenance', 30),
];

/// 临时不可调度规则区块(所有类型,写入 credentials)。
class TempUnschedulableSection extends StatefulWidget {
  const TempUnschedulableSection({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final TempUnschedValue value;
  final ValueChanged<TempUnschedValue> onChanged;
  final bool enabled;

  @override
  State<TempUnschedulableSection> createState() =>
      _TempUnschedulableSectionState();
}

class _TempUnschedulableSectionState extends State<TempUnschedulableSection> {
  late TempUnschedValue _v;
  // 每条规则维持一组控制器。
  late List<_RuleCtrls> _ctrls;

  @override
  void initState() {
    super.initState();
    _v = widget.value;
    _ctrls = [for (final r in _v.rules) _RuleCtrls.from(r)];
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _emit() => widget.onChanged(_v);

  void _add([_Preset? p]) {
    final rule = p == null
        ? TempUnschedRule()
        : TempUnschedRule(
            errorCode: p.code, keywords: p.keywords, durationMinutes: p.minutes);
    setState(() {
      _v.rules.add(rule);
      _ctrls.add(_RuleCtrls.from(rule));
    });
    _emit();
  }

  void _remove(int i) {
    setState(() {
      _v.rules.removeAt(i);
      _ctrls.removeAt(i).dispose();
    });
    _emit();
  }

  void _move(int i, int delta) {
    final j = i + delta;
    if (j < 0 || j >= _v.rules.length) return;
    setState(() {
      final r = _v.rules.removeAt(i);
      _v.rules.insert(j, r);
      final c = _ctrls.removeAt(i);
      _ctrls.insert(j, c);
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('adminAccounts.tempUnsched.title'),
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600)),
                Text(context.tr('adminAccounts.tempUnsched.hint'),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Switch(
            value: _v.enabled,
            onChanged: widget.enabled
                ? (val) {
                    setState(() => _v.enabled = val);
                    _emit();
                  }
                : null,
          ),
        ]),
        if (_v.enabled) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final p in _presets)
                ActionChip(
                  label: Text(
                      '+ ${context.tr('adminAccounts.tempUnsched.preset.${p.label}')}'),
                  onPressed: widget.enabled ? () => _add(p) : null,
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _ctrls.length; i++) _ruleCard(theme, i),
          OutlinedButton.icon(
            onPressed: widget.enabled ? () => _add() : null,
            icon: const Icon(Icons.add, size: 18),
            label: Text(context.tr('adminAccounts.tempUnsched.addRule')),
          ),
        ],
      ],
    );
  }

  Widget _ruleCard(ThemeData theme, int i) {
    final c = _ctrls[i];
    final r = _v.rules[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(context.tr('adminAccounts.tempUnsched.ruleIndex',
                params: {'index': '${i + 1}'})),
            const Spacer(),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: widget.enabled && i > 0 ? () => _move(i, -1) : null,
              icon: const Icon(Icons.arrow_upward, size: 18),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: widget.enabled && i < _ctrls.length - 1
                  ? () => _move(i, 1)
                  : null,
              icon: const Icon(Icons.arrow_downward, size: 18),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: widget.enabled ? () => _remove(i) : null,
              icon: Icon(Icons.close,
                  size: 18, color: theme.colorScheme.error),
            ),
          ]),
          Row(children: [
            Expanded(
              child: TextField(
                controller: c.code,
                enabled: widget.enabled,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.tr('adminAccounts.tempUnsched.errorCode'),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (t) {
                  r.errorCode = int.tryParse(t.trim());
                  _emit();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: c.duration,
                enabled: widget.enabled,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.tr('adminAccounts.tempUnsched.duration'),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (t) {
                  r.durationMinutes = int.tryParse(t.trim());
                  _emit();
                },
              ),
            ),
          ]),
          const SizedBox(height: 8),
          TextField(
            controller: c.keywords,
            enabled: widget.enabled,
            decoration: InputDecoration(
              labelText: context.tr('adminAccounts.tempUnsched.keywords'),
              helperText: context.tr('adminAccounts.tempUnsched.keywordsHint'),
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            onChanged: (t) {
              r.keywords = t;
              _emit();
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: c.description,
            enabled: widget.enabled,
            decoration: InputDecoration(
              labelText: context.tr('adminAccounts.tempUnsched.description'),
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            onChanged: (t) {
              r.description = t;
              _emit();
            },
          ),
        ],
      ),
    );
  }
}

class _RuleCtrls {
  _RuleCtrls(this.code, this.duration, this.keywords, this.description);
  factory _RuleCtrls.from(TempUnschedRule r) => _RuleCtrls(
        TextEditingController(text: r.errorCode?.toString() ?? ''),
        TextEditingController(text: r.durationMinutes?.toString() ?? ''),
        TextEditingController(text: r.keywords),
        TextEditingController(text: r.description),
      );
  final TextEditingController code;
  final TextEditingController duration;
  final TextEditingController keywords;
  final TextEditingController description;
  void dispose() {
    code.dispose();
    duration.dispose();
    keywords.dispose();
    description.dispose();
  }
}
