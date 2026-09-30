import 'package:flutter/material.dart';

/// A vertical story reader with a "cover" transition: the next card slides
/// up over the current one, which drifts upward slowly and dims beneath it.
///
/// The previous version held the incoming card back (a reveal lag) while the
/// outgoing one lifted extra, which opened a strip of bare background between
/// them mid-swipe. Here the cards always overlap — the outgoing card moves
/// slower than the page, the incoming one tracks the finger exactly — so
/// something is painted on every pixel for the whole gesture.
///
/// PageView paints later pages on top, which is exactly the order a cover
/// needs: the incoming card is always above the one it is covering. The same
/// maths runs in reverse when swiping back down.
class FlipPageView extends StatelessWidget {
  const FlipPageView({
    super.key,
    required this.controller,
    required this.itemCount,
    required this.itemBuilder,
    this.onPageChanged,
    this.allowImplicitScrolling = true,
  });

  final PageController controller;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final ValueChanged<int>? onPageChanged;

  /// Builds the neighbouring card ahead of the swipe so its image is already
  /// decoding by the time it is revealed.
  final bool allowImplicitScrolling;

  /// Share of the pager's movement cancelled for the outgoing card. At 0.7 it
  /// travels 30% of the distance, which reads as it staying put underneath
  /// while still feeling attached to the gesture.
  static const double _parallax = 0.7;

  /// Peak darkness over the outgoing card, reached as it is fully covered.
  static const double _maxScrim = 0.5;

  /// Darkness of the shadow cast above the incoming card's top edge.
  static const double _maxShadow = 0.22;

  /// Height of that shadow.
  static const double _shadowHeight = 24;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pageHeight = constraints.maxHeight;

        return PageView.builder(
          controller: controller,
          scrollDirection: Axis.vertical,
          itemCount: itemCount,
          onPageChanged: onPageChanged,
          allowImplicitScrolling: allowImplicitScrolling,
          // Clamping removes the Android overscroll glow, which reads as jank.
          physics: const ClampingScrollPhysics(),
          itemBuilder: (context, index) {
            final child = itemBuilder(context, index);

            return AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                double page;
                try {
                  // `page` is only valid once the view has laid out and a
                  // scroll position is attached; before the first frame it
                  // throws rather than returning null.
                  page = controller.page ?? controller.initialPage.toDouble();
                } catch (_) {
                  page = index.toDouble();
                }

                final delta = (index - page).clamp(-1.0, 1.0);

                // Settled card: no transform at all, so a story at rest is
                // pixel-exact and its text never sits on a transformed layer.
                if (delta == 0) return child;

                return delta < 0
                    ? _outgoing(child, -delta, pageHeight)
                    : _incoming(child, delta);
              },
            );
          },
        );
      },
    );
  }

  /// The card being covered. Pushed back down against the pager so it only
  /// drifts up slowly, and dimmed so it reads as sinking under the new one.
  Widget _outgoing(Widget child, double progress, double pageHeight) {
    return Transform.translate(
      offset: Offset(0, parallaxAt(progress, pageHeight)),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          child,
          // Ignore pointers: the scrim is decoration and must never eat a tap
          // meant for the story underneath it.
          IgnorePointer(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: scrimAt(progress)),
            ),
          ),
        ],
      ),
    );
  }

  /// The card sliding in on top. It tracks the finger exactly — no lag, no
  /// scale — and casts a soft shadow onto the card it is covering.
  Widget _incoming(Widget child, double delta) {
    final shadow = shadowAt(delta);
    if (shadow == 0) return child;

    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -_shadowHeight,
          left: 0,
          right: 0,
          height: _shadowHeight,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: shadow),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Downward offset applied to the outgoing card at a given progress.
  @visibleForTesting
  static double parallaxAt(double progress, double pageHeight) =>
      progress.clamp(0.0, 1.0) * pageHeight * _parallax;

  /// Scrim opacity over the outgoing card.
  @visibleForTesting
  static double scrimAt(double progress) =>
      progress.clamp(0.0, 1.0) * _maxScrim;

  /// Shadow opacity above the incoming card. Full while it travels, fading
  /// over the last stretch so it is gone by the time the card lands.
  @visibleForTesting
  static double shadowAt(double delta) =>
      (delta.clamp(0.0, 1.0) * 6).clamp(0.0, 1.0) * _maxShadow;
}
