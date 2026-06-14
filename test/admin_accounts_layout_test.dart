import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 复现账号池搜索栏的布局结构(含 Expanded 的 Row 处于无界高度的 Column 中),
/// 防止「BoxConstraints forces an infinite width」回归:尾部用 IconButton(宽度有界)
/// 且整行包 SizedBox 给定高度。
void main() {
  testWidgets('搜索栏布局:Row(Expanded TextField + 尾部按钮) 在无界高度 Column 中不报错',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(10),
                child: SizedBox(
                  height: 52,
                  child: Row(
                    children: [
                      const Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Badge.count(
                        count: 3,
                        child: IconButton.filledTonal(
                          onPressed: () {},
                          icon: const Icon(Icons.tune),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(child: ListView(children: const [Text('x')])),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
