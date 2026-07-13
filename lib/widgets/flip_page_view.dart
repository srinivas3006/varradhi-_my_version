import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A vertical paging view that mimics a "flipping magazine page" transition:
/// as you swipe up, the current card folds upward around its top edge (like
/// a page closing away from you) while the next card rises into place from
/// below. This is the distinctive swipe feel Way2News uses for its news
/// card feed, as opposed to a flat slide (the default PageView behavior).
class FlipPageView extends StatelessWidget {
  final PageController controller;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  const FlipPageView({
    super.key,
    required this.controller,
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: controller,
      scrollDirection: Axis.vertical,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        final child = itemBuilder(context, index);
        return AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            double page;
            try {
              // .page is only valid once the PageView has laid out and a
              // scroll position is attached; fall back to the initial page
              // (usually 0) before that first frame.
              page = controller.page ?? controller.initialPage.toDouble();
            } catch (_) {
              page = index.toDouble();
            }

            final delta = (index - page).clamp(-1.0, 1.0);

            if (delta <= 0) {
              // This card is either fully in view (delta == 0) or being
              // swiped away above the viewport (delta -> -1). Fold it
              // upward around its top edge, like a page closing shut.
              final angle = delta * (math.pi / 2.1);
              return Transform(
                alignment: Alignment.topCenter,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0015) // perspective
                  ..rotateX(angle),
                child: Opacity(
                  opacity: (1 + delta).clamp(0.0, 1.0),
                  child: child,
                ),
              );
            } else {
              // This card is queued below, rising into place. Scale/fade it
              // in slightly rather than a flat slide-up.
              final scale = 0.94 + (1 - delta) * 0.06;
              return Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: (1 - delta * 0.5).clamp(0.0, 1.0),
                  child: child,
                ),
              );
            }
          },
        );
      },
    );
  }
}
