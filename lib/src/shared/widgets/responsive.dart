import 'package:flutter/material.dart';

/// 断点(按可用宽度划分)。
enum Breakpoint { compact, medium, expanded }

/// 断点阈值。
const double kMediumBreakpoint = 700;
const double kExpandedBreakpoint = 1100;

extension ResponsiveContext on BuildContext {
  /// 当前窗口宽度对应的断点。
  Breakpoint get breakpoint {
    final w = MediaQuery.sizeOf(this).width;
    if (w >= kExpandedBreakpoint) return Breakpoint.expanded;
    if (w >= kMediumBreakpoint) return Breakpoint.medium;
    return Breakpoint.compact;
  }

  /// 是否为宽屏(≥medium):用于决定多列/分栏。
  bool get isWide => MediaQuery.sizeOf(this).width >= kMediumBreakpoint;
}

/// 按可用宽度计算列数:每列至少 [minTileWidth],最多 [max] 列,至少 1 列。
int responsiveColumns(double width,
    {double minTileWidth = 320, int max = 3}) {
  if (width <= 0) return 1;
  final n = (width / minTileWidth).floor();
  return n.clamp(1, max);
}

/// 桌面/宽屏适配:把页面正文限制最大宽度并水平居中,避免内容被无限拉伸。
/// 仅约束正文宽度(顶栏/底栏仍占满),纵向交给内部滚动视图。
///
/// 用法约定:表单/阅读流用较窄上限(~520);内容/列表/分栏页用较宽上限(~1100)。
class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = 840,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// 响应式卡片栅格:按可用宽度把等宽卡片铺成 1~[maxColumns] 列。
/// 窄屏退化为单列(与原 ListView 视觉一致);卡片高度不一时按行顶对齐。
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minTileWidth = 340,
    this.maxColumns = 3,
    this.spacing = 10,
    this.runSpacing = 10,
  });

  final List<Widget> children;
  final double minTileWidth;
  final int maxColumns;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = responsiveColumns(
          constraints.maxWidth,
          minTileWidth: minTileWidth,
          max: maxColumns,
        );
        if (columns <= 1) {
          // 单列:直接竖排,避免 Wrap 的额外计算。
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: runSpacing),
                children[i],
              ],
            ],
          );
        }
        final tileWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final child in children)
              SizedBox(width: tileWidth, child: child),
          ],
        );
      },
    );
  }
}

/// 宽屏左右分栏、窄屏上下堆叠。比例由 [startFlex]:[endFlex] 决定。
class ResponsiveTwoPane extends StatelessWidget {
  const ResponsiveTwoPane({
    super.key,
    required this.start,
    required this.end,
    this.startFlex = 1,
    this.endFlex = 1,
    this.spacing = 16,
    this.breakAt = kMediumBreakpoint,
  });

  final Widget start;
  final Widget end;
  final int startFlex;
  final int endFlex;
  final double spacing;
  final double breakAt;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakAt) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [start, SizedBox(height: spacing), end],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: startFlex, child: start),
            SizedBox(width: spacing),
            Expanded(flex: endFlex, child: end),
          ],
        );
      },
    );
  }
}
