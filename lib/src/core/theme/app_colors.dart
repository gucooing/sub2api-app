import 'package:flutter/material.dart';

/// 品牌色板,取自 Sub2API 官方图标(深蓝底 + 青绿到亮蓝的「S」渐变)。
class AppColors {
  const AppColors._();

  /// 图标背景深蓝,作为品牌主色种子。
  static const Color brandNavy = Color(0xFF1A2E63);

  /// 「S」渐变起点(青绿)。
  static const Color brandGreen = Color(0xFF4ADE80);

  /// 「S」渐变终点(亮蓝),用作主强调色。
  static const Color brandBlue = Color(0xFF3B82F6);

  /// 品牌渐变,可用于按钮、标题、Logo 背景等。
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandGreen, brandBlue],
  );
}
