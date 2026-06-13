import 'package:flutter_test/flutter_test.dart';
import 'package:sub2api/src/shared/widgets/responsive.dart';

void main() {
  group('responsiveColumns', () {
    test('窄屏单列,宽屏按 minTileWidth 增列并受 max 限制', () {
      expect(responsiveColumns(360, minTileWidth: 340, max: 3), 1);
      expect(responsiveColumns(700, minTileWidth: 340, max: 3), 2);
      expect(responsiveColumns(1100, minTileWidth: 340, max: 3), 3);
      // 超过 max 仍封顶。
      expect(responsiveColumns(2000, minTileWidth: 340, max: 3), 3);
      // 非法宽度兜底 1 列。
      expect(responsiveColumns(0), 1);
      expect(responsiveColumns(-10), 1);
    });
  });
}
