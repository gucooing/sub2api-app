import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/server/server_profile.dart';
import '../../core/server/server_store.dart';
import '../../i18n/app_localizations.dart';
import '../../shared/widgets/confirm_dialog.dart';

/// 服务器管理页:列表选择激活后端、添加/编辑/删除。
/// 登录前后均可进入;切换激活服务器后会话层自动针对新后端恢复登录态。
class ServersScreen extends ConsumerWidget {
  const ServersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(serverStoreProvider);
    final store = ref.read(serverStoreProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('servers.title'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditDialog(context, store),
        icon: const Icon(Icons.add),
        label: Text(context.tr('servers.add')),
      ),
      body: RadioGroup<String>(
        groupValue: state.activeId,
        onChanged: (id) {
          if (id != null) store.setActive(id);
        },
        child: ListView.separated(
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: state.servers.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final server = state.servers[index];
            final isActive = server.id == state.activeId;
            return RadioListTile<String>(
              value: server.id,
              title: Row(
                children: [
                  Flexible(child: Text(server.name)),
                  if (server.builtIn) ...[
                    const SizedBox(width: 8),
                    _Tag(text: context.tr('servers.builtinTag')),
                  ],
                ],
              ),
              subtitle: Text(server.baseUrl),
              secondary: MenuAnchor(
                builder: (context, controller, _) => IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () =>
                      controller.isOpen ? controller.close() : controller.open(),
                ),
                menuChildren: [
                  MenuItemButton(
                    leadingIcon: const Icon(Icons.edit_outlined),
                    onPressed: () =>
                        _showEditDialog(context, store, server: server),
                    child: Text(context.tr('common.edit')),
                  ),
                  MenuItemButton(
                    leadingIcon: const Icon(Icons.delete_outline),
                    onPressed: (server.builtIn || isActive)
                        ? null
                        : () => _confirmDelete(context, store, server),
                    child: Text(context.tr('common.delete')),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _showEditDialog(BuildContext context, ServerStore store,
      {ServerProfile? server}) async {
    await showServerEditDialog(context, store, server: server);
  }

  Future<void> _confirmDelete(
      BuildContext context, ServerStore store, ServerProfile server) async {
    final confirmed = await showConfirmDialog(
      context,
      title: context.tr('common.delete'),
      message:
          context.tr('servers.deleteConfirm', params: {'name': server.name}),
      confirmLabel: context.tr('common.delete'),
      destructive: true,
    );
    if (confirmed) await store.remove(server.id);
  }
}

/// 添加/编辑服务器对话框。返回受影响的服务器 id(取消则 null)。
/// 控制器随对话框生命周期创建与释放,避免 await showDialog 返回后立即 dispose
/// 与关闭动画产生「used after disposed」。
Future<String?> showServerEditDialog(
  BuildContext context,
  ServerStore store, {
  ServerProfile? server,
}) =>
    showDialog<String>(
      context: context,
      builder: (context) => _ServerEditDialog(store: store, server: server),
    );

class _ServerEditDialog extends StatefulWidget {
  const _ServerEditDialog({required this.store, this.server});

  final ServerStore store;
  final ServerProfile? server;

  @override
  State<_ServerEditDialog> createState() => _ServerEditDialogState();
}

class _ServerEditDialogState extends State<_ServerEditDialog> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.server?.name ?? '');
  late final TextEditingController _urlController =
      TextEditingController(text: widget.server?.baseUrl ?? '');
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  bool get _isBuiltIn => widget.server?.builtIn ?? false;

  Future<void> _save() async {
    if (!_isBuiltIn && !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    String? resultId;
    if (widget.server == null) {
      resultId = await widget.store.add(_nameController.text, _urlController.text);
    } else {
      await widget.store.update(
        widget.server!.id,
        name: _nameController.text,
        baseUrl: _isBuiltIn ? null : _urlController.text,
      );
      resultId = widget.server!.id;
    }
    if (mounted) Navigator.of(context).pop(resultId);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.server == null
          ? context.tr('servers.add')
          : context.tr('servers.edit')),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: context.tr('servers.name'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _urlController,
                enabled: !_isBuiltIn,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: context.tr('servers.address'),
                  hintText: 'https://api.example.com',
                  border: const OutlineInputBorder(),
                ),
                validator: (v) =>
                    ServerProfile.normalizeBaseUrl(v ?? '') == null
                        ? context.tr('servers.invalidAddress')
                        : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: _saving ? null : _save,
          child: Text(context.tr('common.save')),
        ),
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('common.cancel')),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: scheme.onSecondaryContainer),
      ),
    );
  }
}
