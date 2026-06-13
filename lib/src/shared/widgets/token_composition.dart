import 'package:flutter/material.dart';

import '../format/formatters.dart';

/// Token 构成的单段(标签 + 数量 + 颜色)。
class TokenSegment {
  const TokenSegment({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;
}

/// Token 构成可视化:堆叠占比条 + 图例(数量)。
///
/// 用于把 输入/输出/缓存创建/缓存读取 的占比与数量一并展示
/// (对齐网页端的「缓存情况」展示)。纯 UI,标签由调用方按 i18n 传入。
class TokenComposition extends StatelessWidget {
  const TokenComposition({super.key, required this.segments});

  final List<TokenSegment> segments;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = segments.fold<int>(0, (a, s) => a + s.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: total <= 0
                ? ColoredBox(color: scheme.surfaceContainerHighest)
                : Row(
                    children: [
                      for (final s in segments)
                        if (s.value > 0)
                          Expanded(
                            flex: s.value,
                            child: ColoredBox(color: s.color),
                          ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            for (final s in segments)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    margin: const EdgeInsets.only(right: 6),
                    decoration:
                        BoxDecoration(color: s.color, shape: BoxShape.circle),
                  ),
                  Text(
                    '${s.label} ',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  Text(
                    formatCompact(s.value),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
