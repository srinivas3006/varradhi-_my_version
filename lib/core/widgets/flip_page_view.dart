import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A vertical story reader: cards move past each other with depth, rather
/// than a flat slide or a zoom.
///
/// The previous version drove the transition with `Transform.scale` from 0.94
/// to 1.0 and nothing else, which is why swiping read as zooming in and out
/// — scale was the only thing actually changing.
///
/// Here **translation is the primary motion**. The outgoing card lifts away
/// and tilts back very slightly while a scrim deepens over it; the incoming
/// card is revealed from behind by moving *slower* than the page itself, and
/// settles to its natural size. Scale is deliberately a finishing touch
/// (0.985 → 1.0), not the effect — the intended hierarchy is
/// translation > scrim > scale > rotation.
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

  /// How far the outgoing card tilts, in radians — about 1.5°.
  ///
  /// Barely perceptible on purpose. The intended hierarchy is
  /// translation > scrim > scale > rotation, so rotation is the faintest
  /// signal of the four: enough to hint at depth, not enough to read as a
  /// card being turned over.
  static const double _maxTilt = 0.026;

  /// How much the incoming card lags the page. It travels 82% of the distance
  /// the pager moves it, so the remaining 18% reads as it being *behind*.
  static const double _revealLag = 0.18;

  /// The incoming card's starting size: a 1.5% change over the whole gesture.
  ///
  /// Deliberately almost nothing. Scale was the *only* thing moving in the
  /// original implementation, which is precisely why it read as zooming.
  static const double _incomingScale = 0.985;

  /// Peak darkness over the outgoing card.
  static const double _maxScrim = 0.45;

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
                // pixel-exact and its text never sits on a scaled layer.
                if (delta == 0) return child;

                return delta < 0
                    ? _outgoing(child, delta, pageHeight)
                    : _incoming(child, delta, pageHeight);
              },
            );
          },
        );
      },
    );
  }

  /// The card being swiped away above. Lifts, tilts back a little, and darkens
  /// as it goes — the darkening is what sells it as passing *behind* rather
  /// than simply leaving.
  Widget _outgoing(Widget child, double delta, double pageHeight) {
    final progress = -delta; // 0 → 1 as it leaves

    return Transform(
      alignment: Alignment.topCenter,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0012) // perspective
        // A little extra lift on top of the pager's own movement, so the card
        // accelerates away instead of tracking the finger exactly.
        ..translateByDouble(0.0, -progress * pageHeight * 0.06, 0.0, 1.0)
        ..rotateX(progress * _maxTilt),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          child,
          // Ignore pointers: the scrim is decoration and must never eat a tap
          // meant for the story underneath it.
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: progress * _maxScrim),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The card rising into place from below. Revealed rather than slid: it
  /// lags the pager, so the outgoing card appears to uncover it.
  Widget _incoming(Widget child, double delta, double pageHeight) {
    final settled = 1 - delta; // 0 → 1 as it arrives

    return Transform.translate(
      // Positive: hold it back down the screen against the pager's motion.
      offset: Offset(0, delta * pageHeight * _revealLag),
      child: Transform.scale(
        scale: _incomingScale + (1 - _incomingScale) * settled,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            child,
            // A soft edge along the top, so the card reads as sitting under
            // the one leaving rather than butting against it.
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                    colors: [
                      Colors.black.withValues(alpha: delta * 0.28),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Exposed for tests: the tilt applied at a given swipe progress.
  @visibleForTesting
  static double tiltAt(double progress) => progress.clamp(0.0, 1.0) * _maxTilt;

  /// Exposed for tests: the incoming card's scale at a given swipe delta.
  @visibleForTesting
  static double incomingScaleAt(double delta) {
    final settled = 1 - delta.clamp(0.0, 1.0);
    return _incomingScale + (1 - _incomingScale) * settled;
  }

  /// Exposed for tests: how far the incoming card lags the pager.
  @visibleForTesting
  static double revealLagAt(double delta, double pageHeight) =>
      delta.clamp(0.0, 1.0) * pageHeight * _revealLag;

  /// Exposed for tests: scrim opacity over the outgoing card.
  @visibleForTesting
  static double scrimAt(double progress) =>
      progress.clamp(0.0, 1.0) * _maxScrim;

  /// Degrees, for a readable assertion.
  @visibleForTesting
  static double get maxTiltDegrees => _maxTilt * 180 / math.pi;
}
