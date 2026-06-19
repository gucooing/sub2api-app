import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../i18n/app_localizations.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/date_time_field.dart';
import '../data/admin_proxies_api.dart';
import '../providers/admin_proxies_providers.dart';

const _protocols = ['http', 'https', 'socks5', 'socks5h'];
const _fallbacks = ['none', 'proxy', 'direct'];

/// 代理新增/编辑(全功能对照 web:协议/主机/端口/认证/过期/回退/备用代理/过期预警)。
class ProxyEditPage extends ConsumerStatefulWidget {
  const ProxyEditPage({super.key, this.proxyId, this.initial});

  final int? proxyId;
  final Proxy? initial;

  bool get isEditing => proxyId != null;

  @override
  ConsumerState<ProxyEditPage> createState() => _ProxyEditPageState();
}

class _ProxyEditPageState extends ConsumerState<ProxyEditPage> {
  final _nameCtrl = TextEditingController();
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _warnCtrl = TextEditingController();
  String _protocol = 'http';
  String _fallback = 'none';
  String _status = 'active';
  int? _backupProxyId;
  DateTime? _expiresAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    if (p != null) {
      _nameCtrl.text = p.name;
      _hostCtrl.text = p.host;
      _portCtrl.text = '${p.port}';
      _userCtrl.text = p.username ?? '';
      _warnCtrl.text = p.expiryWarnDays == null ? '' : '${p.expiryWarnDays}';
      _protocol = p.protocol;
      _fallback = p.fallbackMode;
      _status = p.status == 'inactive' ? 'inactive' : 'active';
      _backupProxyId = p.backupProxyId;
      _expiresAt = p.expiresAt == null
          ? null
          : DateTime.tryParse(p.expiresAt!)?.toLocal();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _warnCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = (ref.watch(adminProxiesAllListProvider).value ?? const [])
        .where((p) => p.id != widget.proxyId)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(
            widget.isEditing ? 'adminProxies.editTitle' : 'adminProxies.create')),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(context.tr('common.save')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: context.tr('adminProxies.name'),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _protocol,
            decoration: InputDecoration(
              labelText: context.tr('adminProxies.protocol'),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              for (final p in _protocols)
                DropdownMenuItem(value: p, child: Text(p.toUpperCase())),
            ],
            onChanged: (v) => setState(() => _protocol = v ?? 'http'),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _hostCtrl,
                decoration: InputDecoration(
                  labelText: context.tr('adminProxies.host'),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _portCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.tr('adminProxies.port'),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _userCtrl,
                decoration: InputDecoration(
                  labelText: context.tr('adminProxies.username'),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _passCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: context.tr('adminProxies.password'),
                  helperText: widget.isEditing
                      ? context.tr('adminProxies.passwordKeepHint')
                      : null,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          DateTimeField(
            label: context.tr('adminProxies.expiresAt'),
            emptyHint: context.tr('adminProxies.neverExpires'),
            value: _expiresAt,
            onChanged: (d) => setState(() => _expiresAt = d),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _warnCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.tr('adminProxies.expiryWarnDays'),
              helperText: context.tr('adminProxies.expiryWarnHint'),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _fallback,
            decoration: InputDecoration(
              labelText: context.tr('adminProxies.fallbackMode'),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              for (final f in _fallbacks)
                DropdownMenuItem(
                    value: f, child: Text(context.tr('adminProxies.fallback_$f'))),
            ],
            onChanged: (v) => setState(() => _fallback = v ?? 'none'),
          ),
          if (_fallback == 'proxy') ...[
            const SizedBox(height: 14),
            DropdownButtonFormField<int?>(
              initialValue: _backupProxyId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: context.tr('adminProxies.backupProxy'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                DropdownMenuItem(
                    value: null, child: Text(context.tr('adminProxies.none'))),
                for (final p in all)
                  DropdownMenuItem(
                      value: p.id,
                      child: Text('${p.name} (${p.endpoint})',
                          overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => _backupProxyId = v),
            ),
          ],
          if (widget.isEditing) ...[
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: InputDecoration(
                labelText: context.tr('adminProxies.status'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                for (final s in ['active', 'inactive'])
                  DropdownMenuItem(
                      value: s, child: Text(context.tr('adminProxies.status_$s'))),
              ],
              onChanged: (v) => setState(() => _status = v ?? 'active'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty ||
        _hostCtrl.text.trim().isEmpty ||
        int.tryParse(_portCtrl.text.trim()) == null) {
      showAppToast(context, context.tr('adminProxies.errRequired'), error: true);
      return;
    }
    setState(() => _saving = true);
    final unix =
        _expiresAt == null ? 0 : _expiresAt!.millisecondsSinceEpoch ~/ 1000;
    final warn = int.tryParse(_warnCtrl.text.trim());
    final body = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'protocol': _protocol,
      'host': _hostCtrl.text.trim(),
      'port': int.parse(_portCtrl.text.trim()),
      'username': _userCtrl.text.trim(),
      'expires_at': unix,
      'fallback_mode': _fallback,
      'backup_proxy_id': _fallback == 'proxy' ? _backupProxyId : null,
      'expiry_warn_days': ?warn,
    };
    // 密码:新增必带;编辑留空则不改。
    if (!widget.isEditing || _passCtrl.text.isNotEmpty) {
      body['password'] = _passCtrl.text;
    }
    if (widget.isEditing) body['status'] = _status;
    try {
      final api = ref.read(adminProxiesApiProvider);
      if (widget.isEditing) {
        await api.update(widget.proxyId!, body);
      } else {
        await api.create(body);
      }
      if (!mounted) return;
      showAppToast(context, context.tr('common.done'));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppToast(context, '$e', error: true);
    }
  }
}
