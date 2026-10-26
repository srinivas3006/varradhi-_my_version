import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaaradhi/widgets/news_action_button.dart';

Widget _host(Widget child, {bool reduceMotion = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(body: Center(child: child)),
      ),
    );

/// The pastel action buttons (Spotlight + article detail).
void main() {
  testWidgets('a neutral like: grey icon, no pastel circle', (t) async {
    await t.pumpWidget(_host(NewsActionButton(
      action: NewsAction.like,
      icon: Icons.thumb_up_alt_outlined,
      idleColor: Colors.grey,
      onTap: () {},
    )));
    final icon = t.widget<Icon>(find.byIcon(Icons.thumb_up_alt_outlined));
    expect(icon.color, Colors.grey);
    final box = t.widget<AnimatedContainer>(find.byType(AnimatedContainer));
    expect((box.decoration as BoxDecoration).color, Colors.transparent);
  });

  testWidgets('an active like: red icon on the pink circle', (t) async {
    await t.pumpWidget(_host(NewsActionButton(
      action: NewsAction.like,
      icon: Icons.thumb_up_rounded,
      isActive: true,
      onTap: () {},
    )));
    await t.pumpAndSettle();
    final icon = t.widget<Icon>(find.byIcon(Icons.thumb_up_rounded));
    expect(icon.color, NewsActionPalette.like.primary);
    final box = t.widget<AnimatedContainer>(find.byType(AnimatedContainer));
    expect((box.decoration as BoxDecoration).color,
        NewsActionPalette.like.pastel);
  });

  testWidgets('the handler runs at once, not after the animation',
      (t) async {
    var taps = 0;
    await t.pumpWidget(_host(NewsActionButton(
      action: NewsAction.comment,
      icon: Icons.chat_bubble_outline_rounded,
      onTap: () => taps++,
    )));
    await t.tap(find.byIcon(Icons.chat_bubble_outline_rounded));
    expect(taps, 1);
    await t.pumpAndSettle();
  });

  testWidgets('rapid taps while a reaction is in flight send one request',
      (t) async {
    var calls = 0;
    final pending = Completer<void>();
    await t.pumpWidget(_host(NewsActionButton(
      action: NewsAction.like,
      icon: Icons.thumb_up_alt_outlined,
      guardWhileBusy: true,
      onTap: () {
        calls++;
        return pending.future;
      },
    )));
    for (var i = 0; i < 4; i++) {
      await t.tap(find.byIcon(Icons.thumb_up_alt_outlined));
      await t.pump(const Duration(milliseconds: 30));
    }
    expect(calls, 1);
    pending.complete();
    await t.pumpAndSettle();
    await t.tap(find.byIcon(Icons.thumb_up_alt_outlined));
    expect(calls, 2, reason: 'free again once the request finished');
    await t.pumpAndSettle();
  });

  testWidgets('a failed (rolled-back) like ends neutral, no burst left',
      (t) async {
    var active = false;
    late StateSetter set;
    await t.pumpWidget(_host(StatefulBuilder(builder: (c, s) {
      set = s;
      return NewsActionButton(
        action: NewsAction.like,
        icon: active ? Icons.thumb_up_rounded : Icons.thumb_up_alt_outlined,
        isActive: active,
        idleColor: Colors.grey,
        onTap: () {},
      );
    })));
    set(() => active = true); // optimistic
    await t.pump(const Duration(milliseconds: 50));
    set(() => active = false); // backend failed: rolled back
    await t.pumpAndSettle();
    expect(t.widget<Icon>(find.byIcon(Icons.thumb_up_alt_outlined)).color,
        Colors.grey);
  });

  testWidgets('the count slides to its new value', (t) async {
    var label = '4';
    late StateSetter set;
    await t.pumpWidget(_host(StatefulBuilder(builder: (c, s) {
      set = s;
      return NewsActionButton(
        action: NewsAction.like,
        icon: Icons.thumb_up_rounded,
        isActive: true,
        label: label,
        onTap: () {},
      );
    })));
    set(() => label = '5');
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('5'), findsOneWidget);
    await t.pumpAndSettle();
    expect(find.text('4'), findsNothing);
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('reduced motion: works, nothing animates', (t) async {
    var taps = 0;
    await t.pumpWidget(_host(
      NewsActionButton(
        action: NewsAction.share,
        icon: Icons.share_rounded,
        filled: true,
        onTap: () => taps++,
      ),
      reduceMotion: true,
    ));
    await t.tap(find.byIcon(Icons.share_rounded));
    expect(taps, 1);
    await t.pump();
    // No press / ripple: the button is at rest at once.
    final scales = t
        .widgetList<Transform>(find.descendant(
            of: find.byType(NewsActionButton), matching: find.byType(Transform)))
        .map((w) => w.transform.getMaxScaleOnAxis());
    expect(scales.every((s) => s == 1.0), isTrue);
  });

  testWidgets('touch target is at least 48 x 48', (t) async {
    await t.pumpWidget(_host(NewsActionButton(
      action: NewsAction.more,
      icon: Icons.more_vert_rounded,
      diameter: 30,
      onTap: () {},
    )));
    final size = t.getSize(find.byType(NewsActionButton));
    expect(size.width, greaterThanOrEqualTo(46));
    expect(size.height, greaterThanOrEqualTo(46));
  });

  testWidgets('controllers are disposed with the button', (t) async {
    await t.pumpWidget(_host(NewsActionButton(
      action: NewsAction.download,
      icon: Icons.download_rounded,
      onTap: () {},
    )));
    await t.tap(find.byIcon(Icons.download_rounded));
    await t.pump(const Duration(milliseconds: 100));
    // Removed mid-animation: no ticker or timer may survive.
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  });

  testWidgets('six buttons fit a small phone without overflow', (t) async {
    t.view.physicalSize = const Size(320 * 2, 640 * 2);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(_host(Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final a in NewsAction.values)
          NewsActionButton(
            action: a,
            icon: Icons.circle,
            label: '1.2k',
            filled: a == NewsAction.share,
            diameter: a == NewsAction.share ? 44 : 40,
            onTap: () {},
          ),
      ],
    )));
    expect(t.takeException(), isNull);
  });

  testWidgets('liking never changes the button height (no bar jump)',
      (t) async {
    var label = ''; // 0 likes: no count shown
    var active = false;
    late StateSetter set;
    await t.pumpWidget(_host(StatefulBuilder(builder: (c, s) {
      set = s;
      return NewsActionButton(
        action: NewsAction.like,
        icon: active ? Icons.thumb_up_rounded : Icons.thumb_up_alt_outlined,
        isActive: active,
        label: label,
        onTap: () {},
      );
    })));
    final before = t.getSize(find.byType(NewsActionButton));
    set(() {
      active = true;
      label = '1';
    });
    for (var i = 0; i < 12; i++) {
      await t.pump(const Duration(milliseconds: 30));
      expect(t.getSize(find.byType(NewsActionButton)), before,
          reason: 'height steady through the animation');
    }
    set(() {
      active = false;
      label = '';
    });
    await t.pumpAndSettle();
    expect(t.getSize(find.byType(NewsActionButton)), before);
  });

  testWidgets('a button without a count is as tall as one with', (t) async {
    await t.pumpWidget(_host(Row(children: [
      NewsActionButton(
          key: const Key('a'),
          action: NewsAction.like,
          icon: Icons.thumb_up_alt_outlined,
          label: '12',
          onTap: () {}),
      NewsActionButton(
          key: const Key('b'),
          action: NewsAction.more,
          icon: Icons.more_vert_rounded,
          onTap: () {}),
    ])));
    expect(t.getSize(find.byKey(const Key('a'))).height,
        t.getSize(find.byKey(const Key('b'))).height);
  });

  testWidgets('share is the #FF0000 filled circle', (t) async {
    await t.pumpWidget(_host(NewsActionButton(
      action: NewsAction.share,
      icon: Icons.share_rounded,
      filled: true,
      onTap: () {},
    )));
    final box = t.widget<AnimatedContainer>(find.byType(AnimatedContainer));
    expect((box.decoration as BoxDecoration).color, const Color(0xFFFF0000));
    expect(t.widget<Icon>(find.byIcon(Icons.share_rounded)).color,
        Colors.white);
  });
}
