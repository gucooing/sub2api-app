import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/session/auth_models.dart';
import '../../core/storage/prefs_store.dart';
import '../../i18n/app_localizations.dart';
import '../../shared/widgets/markdown_text.dart';

String _consentKey(String serverId) => '${PrefKeys.agreementPrefix}$serverId';

/// 是否已同意该服务器当前修订号的条款。无修订号时返回 false(每次都需确认)。
bool isAgreementAccepted(
    SharedPreferences prefs, String serverId, String revision) {
  if (revision.isEmpty) return false;
  return prefs.getString(_consentKey(serverId)) == revision;
}

/// 记住已同意(仅当有修订号)。
Future<void> persistAgreementAccepted(
    SharedPreferences prefs, String serverId, String revision) async {
  if (revision.isNotEmpty) {
    await prefs.setString(_consentKey(serverId), revision);
  }
}

/// 清除已记住的同意(取消勾选时调用)。
Future<void> clearAgreementAccepted(
    SharedPreferences prefs, String serverId) async {
  await prefs.remove(_consentKey(serverId));
}

/// 查看单个条款文档(Markdown 沉浸页)。
void openAgreementDoc(BuildContext context, LoginAgreementDocument doc) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (context) => Scaffold(
      appBar: AppBar(title: Text(doc.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [MarkdownText(doc.contentMd)],
      ),
    ),
  ));
}

/// 条款更新弹窗(modal 模式)。返回 true=同意,false/null=拒绝或关闭。
Future<bool?> showAgreementModal(
  BuildContext context,
  PublicSettingsLite settings,
) {
  final docs = settings.agreementDocuments;
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text(context.tr('agreement.title')),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.tr('agreement.intro'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            for (final doc in docs)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(doc.title),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => openAgreementDoc(context, doc),
                ),
              ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(context.tr('agreement.agree')),
        ),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.tr('agreement.reject')),
        ),
      ],
    ),
  );
}

/// 复选框形式的条款同意:「我已阅读并同意 <文档链接,顿号分隔>」。
class LoginAgreementCheckbox extends StatelessWidget {
  const LoginAgreementCheckbox({
    super.key,
    required this.documents,
    required this.accepted,
    required this.onChanged,
    this.enabled = true,
  });

  final List<LoginAgreementDocument> documents;
  final bool accepted;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final linkStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: accepted,
            onChanged: enabled ? (v) => onChanged(v ?? false) : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text.rich(
              TextSpan(
                style: Theme.of(context).textTheme.bodyMedium,
                children: [
                  TextSpan(text: '${context.tr('agreement.readAndAgree')} '),
                  for (var i = 0; i < documents.length; i++) ...[
                    if (i > 0) const TextSpan(text: '、'),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: GestureDetector(
                        onTap: () => openAgreementDoc(context, documents[i]),
                        child: Text(documents[i].title, style: linkStyle),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
