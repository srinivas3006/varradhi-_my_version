import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every side of every 3D shape shows the advertiser picture', () {
    final src =
        File('lib/widgets/ads/floating_three_d_ad.dart').readAsStringSync();
    final lists = RegExp(r'faces: const \[([^\]]*)\]')
        .allMatches(src)
        .map((m) => m.group(1)!)
        .toList();
    expect(lists, hasLength(4), reason: 'cube, prism, pillar, corner');
    for (final l in lists) {
      expect(l, isNot(contains('_Face.brand')));
      expect(l, isNot(contains('_Face.cta')));
    }
  });
}
