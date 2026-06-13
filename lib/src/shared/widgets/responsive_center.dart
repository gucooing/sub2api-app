import 'package:flutter/material.dart';

/// 桌面/宽屏适配:把页面正文限制最大宽度并水平居中,避免内容被无限拉伸。
/// 仅约束正文宽度(顶栏/底栏仍占满),纵向交给内部滚动视图。
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
