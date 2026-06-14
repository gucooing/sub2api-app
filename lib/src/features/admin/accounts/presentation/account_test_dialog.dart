import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../i18n/app_localizations.dart';
import '../data/admin_accounts_api.dart';
import '../providers/admin_accounts_providers.dart';

/// 测试账号连接:选择模型 + 请求内容(默认 hi)+ 展示请求结果(对照 web AccountTestModal)。
Future<void> showAccountTestDialog(
    BuildContext context, WidgetRef ref, AdminAccount account) {
  return showDialog<void>(
    context: context,
    builder: (_) => _TestDialog(account: account),
  );
}

class _TestDialog extends ConsumerStatefulWidget {
  const _TestDialog({required this.account});
  final AdminAccount account;

  @override
  ConsumerState<_TestDialog> createState() => _TestDialogState();
}

class _TestDialogState extends ConsumerState<_TestDialog> {
  final _prompt = TextEditingController(text: 'hi');
  List<String> _models = [];
  String? _model;
  bool _loadingModels = true;
  bool _testing = false;
  String _result = '';
  bool? _success;

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  Future<void> _loadModels() async {
    try {
      final m = await ref.read(adminAccountsApiProvider).availableModels(widget.account.id);
      if (!mounted) return;
      setState(() {
        _models = m;
        _model = m.isNotEmpty ? m.first : null;
        _loadingModels = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingModels = false);
    }
  }

  Future<void> _runTest() async {
    final model = _model;
    if (model == null) return;
    setState(() {
      _testing = true;
      _result = '';
      _success = null;
    });
    try {
      final raw = await ref
          .read(adminAccountsApiProvider)
          .testRaw(widget.account.id, modelId: model, prompt: _prompt.text.trim());
      final parsed = _parseSse(raw);
      if (mounted) {
        setState(() {
          _result = parsed.$1;
          _success = parsed.$2;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _result = '$e';
          _success = false;
        });
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  /// 解析 SSE 文本:累计 content,捕获 model/error/done。非 SSE(纯 JSON)兜底。
  (String, bool) _parseSse(String raw) {
    final buf = StringBuffer();
    bool? ok;
    for (final line in const LineSplitter().convert(raw)) {
      final t = line.trim();
      if (t.isEmpty) continue;
      final payload = t.startsWith('data:') ? t.substring(5).trim() : t;
      if (payload == '[DONE]') continue;
      try {
        final obj = jsonDecode(payload);
        if (obj is Map) {
          final type = obj['type'];
          if (obj['content'] is String) buf.write(obj['content']);
          if (obj['model'] is String) {
            buf.writeln('[model] ${obj['model']}');
          }
          final msg = obj['message'] ?? obj['error'] ?? obj['detail'];
          if (msg is String && msg.isNotEmpty) buf.writeln(msg);
          if (type == 'error' || obj['error'] != null) ok = false;
          if (type == 'done' || obj['success'] == true) ok ??= true;
          if (obj['success'] == false) ok = false;
          continue;
        }
      } catch (_) {
        // 非 JSON 行,原样附加。
      }
      buf.writeln(payload);
    }
    final text = buf.toString().trim();
    return (text.isEmpty ? '—' : text, ok ?? text.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(context.tr('adminAccounts.testTitle')),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_loadingModels)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              )
            else
              DropdownButtonFormField<String>(
                initialValue: _model,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: context.tr('adminAccounts.testModel'),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final m in _models)
                    DropdownMenuItem(value: m, child: Text(m)),
                ],
                onChanged: _testing ? null : (v) => setState(() => _model = v),
              ),
            const SizedBox(height: 10),
            TextField(
              controller: _prompt,
              enabled: !_testing,
              decoration: InputDecoration(
                labelText: context.tr('adminAccounts.testPrompt'),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
            if (_result.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 220),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _success == false
                        ? scheme.error
                        : scheme.outlineVariant,
                  ),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _result,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontFamily: 'monospace'),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _testing ? null : () => Navigator.of(context).pop(),
          child: Text(context.tr('common.close')),
        ),
        FilledButton(
          onPressed: (_testing || _model == null) ? null : _runTest,
          child: _testing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(context.tr('adminAccounts.runTest')),
        ),
      ],
    );
  }
}
