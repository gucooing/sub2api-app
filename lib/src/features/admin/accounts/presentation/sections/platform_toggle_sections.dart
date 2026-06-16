import 'package:flutter/material.dart';

import '../../../../../i18n/app_localizations.dart';
import '../../../../../shared/widgets/pill_segmented.dart';
import '../../data/account_platform_options.dart';

/// Anthropic API Key 平台开关:自动透传 + 联网搜索模拟(三态)。
class AnthropicApikeySection extends StatefulWidget {
  const AnthropicApikeySection({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final AnthropicApikeyOptions value;
  final ValueChanged<AnthropicApikeyOptions> onChanged;
  final bool enabled;

  @override
  State<AnthropicApikeySection> createState() => _AnthropicApikeySectionState();
}

class _AnthropicApikeySectionState extends State<AnthropicApikeySection> {
  late AnthropicApikeyOptions _v;

  @override
  void initState() {
    super.initState();
    _v = widget.value;
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
                Text(context.tr('adminAccounts.anthropic.passthrough'),
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                Text(context.tr('adminAccounts.anthropic.passthroughHint'),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Switch(
            value: _v.passthrough,
            onChanged: widget.enabled
                ? (b) {
                    setState(() => _v.passthrough = b);
                    widget.onChanged(_v);
                  }
                : null,
          ),
        ]),
        const SizedBox(height: 12),
        Text(context.tr('adminAccounts.anthropic.webSearch'),
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        Text(context.tr('adminAccounts.anthropic.webSearchHint'),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: PillSegmented<String>(
            selected: _v.webSearchMode,
            onChanged: widget.enabled
                ? (m) {
                    setState(() => _v.webSearchMode = m);
                    widget.onChanged(_v);
                  }
                : (_) {},
            options: [
              ('default', context.tr('adminAccounts.anthropic.wsDefault')),
              ('enabled', context.tr('adminAccounts.anthropic.wsEnabled')),
              ('disabled', context.tr('adminAccounts.anthropic.wsDisabled')),
            ],
          ),
        ),
      ],
    );
  }
}

/// Antigravity 平台开关:混合调度(只读)+ 允许超额。
class AntigravitySection extends StatefulWidget {
  const AntigravitySection({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final AntigravityOptions value;
  final ValueChanged<AntigravityOptions> onChanged;
  final bool enabled;

  @override
  State<AntigravitySection> createState() => _AntigravitySectionState();
}

class _AntigravitySectionState extends State<AntigravitySection> {
  late AntigravityOptions _v;

  @override
  void initState() {
    super.initState();
    _v = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 混合调度:只读展示(对照 web 编辑态禁用)。
        Opacity(
          opacity: 0.6,
          child: Row(children: [
            Checkbox(value: _v.mixedScheduling, onChanged: null),
            Expanded(
              child: Text(context.tr('adminAccounts.antigravity.mixedScheduling'),
                  style: theme.textTheme.bodyMedium),
            ),
          ]),
        ),
        Row(children: [
          Checkbox(
            value: _v.allowOverages,
            onChanged: widget.enabled
                ? (b) {
                    setState(() => _v.allowOverages = b ?? false);
                    widget.onChanged(_v);
                  }
                : null,
          ),
          Expanded(
            child: Text(context.tr('adminAccounts.antigravity.allowOverages'),
                style: theme.textTheme.bodyMedium),
          ),
        ]),
      ],
    );
  }
}
