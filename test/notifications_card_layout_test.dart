import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Inbox cards read like news: picture left, 2-line headline, 2-line
/// summary, time below — the time must not share the headline's row
/// (that squeezed headlines to one word per line).
void main() {
  final src = File('lib/screens/notifications_screen.dart').readAsStringSync();

  test('headline and summary are clamped to two lines', () {
    expect(
        RegExp(r'maxLines: 2').allMatches(src).length, greaterThanOrEqualTo(2));
    expect(src, contains('_thumbnail('));
    expect(src, contains('_showMessage('));
  });

  test('time is not in a spaceBetween row beside the headline', () {
    expect(src, isNot(contains('MainAxisAlignment.spaceBetween')));
  });

  test('mark-all-read is an icon so the title fits', () {
    expect(src, contains("Key('notifications_mark_all_read')"));
    expect(
        src, isNot(contains("child: const Text('అన్నీ చదివినట్లు గుర్తించు'")));
  });
}
