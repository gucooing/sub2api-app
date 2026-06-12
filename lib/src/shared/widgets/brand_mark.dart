import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// 品牌标识:渐变圆角方块 + 闪电,用于登录页/关于页等。
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(size / 4),
      ),
      child: Icon(Icons.bolt, size: size * 0.58, color: Colors.white),
    );
  }
}
