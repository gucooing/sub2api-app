import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// 品牌渐变 hero 头(总览/充值/邀请等页面顶部),内部前景统一为白色。
class BrandHeader extends StatelessWidget {
  const BrandHeader({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 22),
    this.borderRadius =
        const BorderRadius.vertical(bottom: Radius.circular(24)),
  });

  final Widget child;
  final EdgeInsets padding;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: borderRadius,
      ),
      child: IconTheme(
        data: const IconThemeData(color: Colors.white),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: Colors.white),
          child: child,
        ),
      ),
    );
  }
}
