import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../i18n/app_localizations.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../data/admin_accounts_api.dart';
import '../providers/admin_accounts_providers.dart';

/// 测试账号连接(对照 web AccountTestModal):账号信息 + 选择模型 + 图像模型的提示词 +
/// 终端实时展示连接/请求/响应过程 + 结果状态 + 图像预览 + 复制输出。
Future<void> showAccountTestDialog(
    BuildContext context, WidgetRef ref, AdminAccount account) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _TestDialog(account: account),
  );
}

enum _Status { idle, connecting, success, error }

class _Line {
  const _Line(this.text, this.color);
  final String text;
  final Color color;
}

const _prioritizedGemini = [
  'gemini-3.1-flash-image',
  'gemini-2.5-flash-image',
  'gemini-3.5-flash',
  'gemini-2.5-flash',
  'gemini-2.5-pro',
  'gemini-3-flash-preview',
  'gemini-3-pro-preview',
  'gemini-2.0-flash',
];

class _TestDialog extends ConsumerStatefulWidget {
  const _TestDialog({required this.account});
  final AdminAccount account;

  @override
  ConsumerState<_TestDialog> createState() => _TestDialogState();
}

class _TestDialogState extends ConsumerState<_TestDialog> {
  final _prompt = TextEditingController();
  final _scroll = ScrollController();

  List<TestModel> _models = [];
  String? _modelId;
  bool _loadingModels = true;

  _Status _status = _Status.idle;
  final List<_Line> _lines = [];
  String _streaming = '';
  String _error = '';
  final List<(String, String?)> _images = [];

  StreamSubscription<AccountTestEvent>? _sub;

  // 终端配色
  static const _cGray = Color(0xFF9CA3AF);
  static const _cBlue = Color(0xFF60A5FA);
  static const _cGreen = Color(0xFF4ADE80);
  static const _cGreenSoft = Color(0xFF86EFAC);
  static const _cCyan = Color(0xFF22D3EE);
  static const _cYellow = Color(0xFFFACC15);
  static const _cPurple = Color(0xFFD8B4FE);
  static const _cRed = Color(0xFFF87171);

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _prompt.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _isGeminiImage {
    final m = (_modelId ?? '').toLowerCase();
    if (!m.startsWith('gemini-') || !m.contains('-image')) return false;
    return widget.account.platform == 'gemini' ||
        (widget.account.platform == 'antigravity' &&
            widget.account.type == 'apikey');
  }

  bool get _isOpenAIImage {
    final m = (_modelId ?? '').toLowerCase();
    return m.startsWith('gpt-image-') && widget.account.platform == 'openai';
  }

  bool get _supportsImage => _isGeminiImage || _isOpenAIImage;

  Future<void> _loadModels() async {
    try {
      var models =
          await ref.read(adminAccountsApiProvider).availableModels(widget.account.id);
      final p = widget.account.platform;
      if (p == 'gemini' || p == 'antigravity') {
        final order = {
          for (var i = 0; i < _prioritizedGemini.length; i++)
            _prioritizedGemini[i]: i
        };
        models = [...models]..sort((a, b) =>
            (order[a.id] ?? 1 << 30).compareTo(order[b.id] ?? 1 << 30));
      }
      String? sel;
      if (models.isNotEmpty) {
        if (p == 'gemini') {
          sel = models.first.id;
        } else {
          sel = models
                  .firstWhere((m) => m.id.contains('sonnet'),
                      orElse: () => models.first)
                  .id;
        }
      }
      if (!mounted) return;
      setState(() {
        _models = models;
        _modelId = sel;
        _loadingModels = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingModels = false);
    }
  }

  void _addLine(String text, Color color) {
    _lines.add(_Line(text, color));
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _start() async {
    final model = _modelId;
    if (model == null) return;
    await _sub?.cancel();
    setState(() {
      _status = _Status.connecting;
      _lines.clear();
      _streaming = '';
      _error = '';
      _images.clear();
      _addLine(
          context.tr('adminAccounts.test.starting', params: {'name': widget.account.name}),
          _cBlue);
      _addLine(
          context.tr('adminAccounts.test.typeLabel', params: {'type': widget.account.type}),
          _cGray);
    });

    final stream = ref.read(adminAccountsApiProvider).testStream(
          widget.account.id,
          modelId: model,
          prompt: _supportsImage ? _prompt.text.trim() : '',
        );
    _sub = stream.listen(
      _handleEvent,
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _status = _Status.error;
          _error = '$e';
          _addLine('Error: $e', _cRed);
        });
      },
      onDone: () {
        if (!mounted) return;
        if (_status == _Status.connecting) {
          setState(() {
            if (_streaming.isNotEmpty) {
              _addLine(_streaming, _cGreenSoft);
              _streaming = '';
            }
            _status = _Status.success;
          });
        }
      },
    );
  }

  void _handleEvent(AccountTestEvent e) {
    if (!mounted) return;
    setState(() {
      switch (e.type) {
        case 'test_start':
          _addLine(context.tr('adminAccounts.test.connected'), _cGreen);
          if ((e.model ?? '').isNotEmpty) {
            _addLine(
                context.tr('adminAccounts.test.usingModel', params: {'model': e.model!}),
                _cCyan);
          }
          _addLine(
              _supportsImage
                  ? context.tr('adminAccounts.test.sendingImage')
                  : context.tr('adminAccounts.test.sendingMessage'),
              _cGray);
          _addLine(context.tr('adminAccounts.test.response'), _cYellow);
        case 'content':
          if ((e.text ?? '').isNotEmpty) {
            _streaming += e.text!;
            _scrollToBottom();
          }
        case 'image':
          if ((e.imageUrl ?? '').isNotEmpty) {
            _images.add((e.imageUrl!, e.mimeType));
            _addLine(
                context.tr('adminAccounts.test.imageReceived',
                    params: {'count': '${_images.length}'}),
                _cPurple);
          }
        case 'test_complete':
          if (_streaming.isNotEmpty) {
            _addLine(_streaming, _cGreenSoft);
            _streaming = '';
          }
          if (e.success == true) {
            _status = _Status.success;
          } else {
            _status = _Status.error;
            _error = e.error ?? context.tr('adminAccounts.test.failed');
          }
        case 'error':
          _status = _Status.error;
          _error = e.error ?? context.tr('adminAccounts.test.failed');
          if (_streaming.isNotEmpty) {
            _addLine(_streaming, _cGreenSoft);
            _streaming = '';
          }
      }
    });
  }

  void _copyOutput() {
    final text = _lines.map((l) => l.text).join('\n');
    Clipboard.setData(ClipboardData(text: text));
    showAppToast(context, context.tr('adminAccounts.test.copied'));
  }

  @override
  Widget build(BuildContext context) {
    final connecting = _status == _Status.connecting;
    return AlertDialog(
      title: Text(context.tr('adminAccounts.testTitle')),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _accountCard(),
              const SizedBox(height: 12),
              if (_loadingModels)
                const LinearProgressIndicator()
              else
                DropdownButtonFormField<String>(
                  initialValue: _modelId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: context.tr('adminAccounts.testModel'),
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (final m in _models)
                      DropdownMenuItem(value: m.id, child: Text(m.displayName)),
                  ],
                  onChanged:
                      connecting ? null : (v) => setState(() => _modelId = v),
                ),
              if (_supportsImage) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _prompt,
                  enabled: !connecting,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: context.tr('adminAccounts.test.imagePrompt'),
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _terminal(),
              if (_images.isNotEmpty) ...[
                const SizedBox(height: 12),
                _imageGrid(),
              ],
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            _sub?.cancel();
            Navigator.of(context).pop();
          },
          child: Text(context.tr('common.close')),
        ),
        FilledButton.icon(
          onPressed: (connecting || _modelId == null) ? null : _start,
          icon: connecting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(_status == _Status.idle ? Icons.play_arrow : Icons.refresh,
                  size: 18),
          label: Text(
            connecting
                ? context.tr('adminAccounts.testing')
                : _status == _Status.idle
                    ? context.tr('adminAccounts.test.start')
                    : context.tr('adminAccounts.test.retry'),
          ),
        ),
      ],
    );
  }

  Widget _accountCard() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.account.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('${widget.account.platform} · ${widget.account.type}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          Text(widget.account.status,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: widget.account.isActive
                      ? _cGreen
                      : scheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _terminal() {
    return Container(
      height: 220,
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0F19),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Stack(
        children: [
          SingleChildScrollView(
            controller: _scroll,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_status == _Status.idle && _lines.isEmpty)
                  Text(context.tr('adminAccounts.test.ready'),
                      style: const TextStyle(
                          color: _cGray, fontFamily: 'monospace', fontSize: 12)),
                if (_status == _Status.connecting && _lines.length <= 2)
                  Text(context.tr('adminAccounts.test.connecting'),
                      style: const TextStyle(
                          color: _cYellow,
                          fontFamily: 'monospace',
                          fontSize: 12)),
                for (final l in _lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 1),
                    child: SelectableText(l.text,
                        style: TextStyle(
                            color: l.color,
                            fontFamily: 'monospace',
                            fontSize: 12)),
                  ),
                if (_streaming.isNotEmpty)
                  SelectableText('$_streaming▌',
                      style: const TextStyle(
                          color: _cGreen,
                          fontFamily: 'monospace',
                          fontSize: 12)),
                if (_status == _Status.success)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(children: [
                      const Icon(Icons.check_circle, size: 14, color: _cGreen),
                      const SizedBox(width: 4),
                      Text(context.tr('adminAccounts.test.completed'),
                          style: const TextStyle(
                              color: _cGreen, fontSize: 12)),
                    ]),
                  ),
                if (_status == _Status.error)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(children: [
                      const Icon(Icons.cancel, size: 14, color: _cRed),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(_error,
                            style: const TextStyle(color: _cRed, fontSize: 12)),
                      ),
                    ]),
                  ),
              ],
            ),
          ),
          if (_lines.isNotEmpty)
            Positioned(
              right: 0,
              top: 0,
              child: IconButton(
                icon: const Icon(Icons.copy, size: 16, color: _cGray),
                tooltip: context.tr('adminAccounts.test.copy'),
                onPressed: _copyOutput,
              ),
            ),
        ],
      ),
    );
  }

  Widget _imageGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final img in _images)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              img.$1,
              width: 140,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox(
                width: 140,
                height: 80,
                child: Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
      ],
    );
  }
}
