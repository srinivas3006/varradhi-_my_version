import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaaradhi/screens/poster_detail_screen.dart';
import 'package:vaaradhi/widgets/poster_card.dart';

void main() {
  testWidgets('the poster screen has a plain share icon bottom-right',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(
      home: PosterDetailScreen(poster: {
        'id': 'p1',
        'title': 'హీరోయిన్ కొత్త ఫోటోలు',
        'images': [
          {'image_url': 'https://cdn.test/a.jpg', 'sort_order': 1},
          {'image_url': 'https://cdn.test/b.jpg', 'sort_order': 2},
        ],
      }),
    ));
    await tester.pump();

    final share = find.byKey(const Key('poster_share'));
    expect(share, findsOneWidget);
    expect(tester.widget(share), isA<IconButton>());
    expect(
        find.descendant(of: share, matching: find.byIcon(Icons.share_rounded)),
        findsOneWidget);

    // No full-width Share bar.
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.text('షేర్ చేయండి'), findsNothing);

    // Bottom-right corner.
    final rect = tester.getRect(share);
    expect(rect.right, greaterThan(390 - 40));
    expect(rect.center.dy, greaterThan(844 / 2));
  });

  testWidgets('the Spotlight poster card has the same plain share icon',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: PosterCard(
            mediaUrl: '', imageUrls: ['', ''], title: 'హీరోయిన్ కొత్త ఫోటోలు'),
      ),
    ));
    await tester.pump();

    final share = find.byKey(const Key('poster_share'));
    expect(share, findsOneWidget);
    expect(tester.widget(share), isA<IconButton>());
    // No full-width orange "షేర్ చేయండి" bar.
    expect(find.byType(FilledButton), findsNothing);
    expect(find.text('షేర్ చేయండి'), findsNothing);

    // Bottom-right, just above Spotlight's bottom bar.
    final rect = tester.getRect(share);
    expect(rect.right, greaterThan(390 - 40));
    expect(rect.bottom, greaterThan(844 - 140));
  });
}
