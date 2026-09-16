import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/widgets/ads/ad_badge.dart';

void main() {
  testWidgets('renders the disclosure text', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: AdBadge()),
    ));
    expect(find.text('Ad'), findsOneWidget);
  });

  testWidgets('positioned top-right and never eats a tap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => tapped = true,
            child: const SizedBox.expand(),
          ),
          AdBadge.positioned(),
        ]),
      ),
    ));

    final badge = tester.getRect(find.byType(AdBadge));
    final screen = tester.getRect(find.byType(SizedBox).first);
    expect(badge.right, lessThanOrEqualTo(screen.right));
    expect(badge.left, greaterThan(screen.width / 2), reason: 'right half');
    expect(badge.top - screen.top, lessThan(screen.height / 2), reason: 'top');

    // The creative underneath stays clickable through the badge.
    await tester.tapAt(badge.center);
    expect(tapped, isTrue);
  });
}
