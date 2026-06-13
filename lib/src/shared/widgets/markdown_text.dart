import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// 统一的 Markdown 文本渲染(公告、说明等)。
///
/// 用 [GptMarkdown] 渲染常见 Markdown(标题/加粗/列表/链接/代码等),
/// 默认继承当前正文样式。
class MarkdownText extends StatelessWidget {
  const MarkdownText(this.data, {super.key, this.style});

  final String data;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return GptMarkdown(
      data,
      style: style ?? Theme.of(context).textTheme.bodyMedium,
    );
  }
}
