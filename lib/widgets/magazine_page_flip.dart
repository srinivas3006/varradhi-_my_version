import 'package:flutter/material.dart';

/// Builder signature — same shape as [IndexedWidgetBuilder], used so you can
/// pass your existing news-card widget builder in unchanged.
typedef PageFlipItemBuilder = Widget Function(BuildContext context, int index);

/// A vertical feed that transitions between items with a "magazine page
/// fold" instead of a slide — replicating the Way2News news-card flip.
///
/// Visual model (matches Way2News exactly):
///  • Swiping UP (going to the next card): the CURRENT card is the "leaf".
///    It rotates around its TOP edge, from 0° to -90°, like a page being
///    turned up and over. As it rotates it darkens (perspective shading).
///    The NEXT card sits underneath, fully visible, and gets revealed as
///    the leaf folds away.
///  • Swiping DOWN (going to the previous card): the PREVIOUS card is the
///    "leaf". It starts folded at -90° (hidden, tucked at the top) and
///    rotates down to 0°, landing on top of the current card, lightening
///    as it settles into place.
///
/// Drop this in wherever you currently have:
///   PageView.builder(
///     scrollDirection: Axis.vertical,
///     itemCount: articles.length,
///     itemBuilder: (context, i) => NewsCard(articles[i]),
///   )
///
/// and replace it with:
///   MagazinePageFlip(
///     itemCount: articles.length,
///     itemBuilder: (context, i) => NewsCard(articles[i]),
///     onPageChanged: (i) => setState(() => currentIndex = i),
///   )
///
/// Every NewsCard/ad-slot/report-flow widget you already have keeps working
/// unchanged — only the transition mechanism between them is replaced.
class MagazinePageFlip extends StatefulWidget {
  const MagazinePageFlip({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.initialIndex = 0,
    this.onPageChanged,
    this.flingDuration = const Duration(milliseconds: 320),
    this.commitThreshold = 0.35,
    this.flingVelocity = 800.0,
  });

  final int itemCount;
  final PageFlipItemBuilder itemBuilder;
  final int initialIndex;
  final ValueChanged<int>? onPageChanged;

  /// How long the settle/snap animation takes once you lift your finger.
  final Duration flingDuration;

  /// Fraction of the screen you must drag before lifting your finger
  /// commits the page change (like PageView's default ~0.35-0.5).
  final double commitThreshold;

  /// Flick speed (px/s) that force-commits the flip even on a short drag.
  final double flingVelocity;

  @override
  State<MagazinePageFlip> createState() => MagazinePageFlipState();
}

class MagazinePageFlipState extends State<MagazinePageFlip>
    with SingleTickerProviderStateMixin {
  late int _index;
  late final AnimationController _ctrl;

  double _dragStartY = 0;
  double _height = 0;

  // -1 = dragging toward NEXT (swipe up), 1 = dragging toward PREVIOUS
  // (swipe down), 0 = idle / no gesture in progress.
  int _direction = 0;

  int get currentIndex => _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _ctrl = AnimationController(vsync: this, duration: widget.flingDuration)
      ..addListener(() => setState(() {}))
      ..addStatusListener(_handleStatus);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _canGoNext => _index < widget.itemCount - 1;
  bool get _canGoPrev => _index > 0;

  void _handleStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (_ctrl.value < 1.0) return; // dismissed back to 0, nothing to commit
    setState(() {
      if (_direction == -1 && _canGoNext) {
        _index += 1;
      } else if (_direction == 1 && _canGoPrev) {
        _index -= 1;
      }
      _direction = 0;
    });
    _ctrl.value = 0;
    widget.onPageChanged?.call(_index);
  }

  void _onDragStart(DragStartDetails d) {
    if (_ctrl.isAnimating) return;
    _dragStartY = d.globalPosition.dy;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_height == 0 || _ctrl.isAnimating) return;
    final dy = d.globalPosition.dy - _dragStartY;

    if (_direction == 0) {
      if (dy < -4 && _canGoNext) {
        _direction = -1;
      } else if (dy > 4 && _canGoPrev) {
        _direction = 1;
      } else {
        return;
      }
    }

    final progress = (dy.abs() / _height).clamp(0.0, 1.0);
    _ctrl.value = progress;
  }

  void _onDragEnd(DragEndDetails d) {
    if (_direction == 0) return;

    final velocity = d.velocity.pixelsPerSecond.dy;
    final flungForward = (_direction == -1 && velocity < -widget.flingVelocity) ||
        (_direction == 1 && velocity > widget.flingVelocity);
    final pastThreshold = _ctrl.value > widget.commitThreshold;

    if (flungForward || pastThreshold) {
      _ctrl.animateTo(1.0, curve: Curves.easeOutCubic);
    } else {
      _ctrl.animateBack(0.0, curve: Curves.easeOutCubic).whenComplete(() {
        if (mounted) setState(() => _direction = 0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _height = constraints.maxHeight;
        final t = _ctrl.value;

        final current = KeyedSubtree(
          key: ValueKey('page_$_index'),
          child: widget.itemBuilder(context, _index),
        );

        Widget stack;

        if (_direction == -1 && _canGoNext) {
          // Swiping UP → next card revealed underneath; current card is
          // the leaf folding away over its top edge.
          final next = KeyedSubtree(
            key: ValueKey('page_${_index + 1}'),
            child: widget.itemBuilder(context, _index + 1),
          );
          final angle = t * (3.1415926535 / 2); // 0 → 90°
          stack = Stack(
            fit: StackFit.expand,
            children: [
              next,
              _FoldingLeaf(angle: -angle, shade: t * 0.45, child: current),
            ],
          );
        } else if (_direction == 1 && _canGoPrev) {
          // Swiping DOWN → previous card folds in from the top, landing
          // on top of the current card.
          final prev = KeyedSubtree(
            key: ValueKey('page_${_index - 1}'),
            child: widget.itemBuilder(context, _index - 1),
          );
          final angle = (1 - t) * (3.1415926535 / 2); // 90° → 0°
          stack = Stack(
            fit: StackFit.expand,
            children: [
              current,
              _FoldingLeaf(angle: -angle, shade: (1 - t) * 0.45, child: prev),
            ],
          );
        } else {
          stack = current;
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: _onDragStart,
          onVerticalDragUpdate: _onDragUpdate,
          onVerticalDragEnd: _onDragEnd,
          child: ClipRect(child: stack),
        );
      },
    );
  }
}

/// The rotating "page" — anchored at its top edge with a perspective
/// transform, plus a shading overlay that darkens as it turns away from
/// the viewer (or lightens as it turns into place), matching the printed
/// look of an actual page fold.
class _FoldingLeaf extends StatelessWidget {
  const _FoldingLeaf({
    required this.angle,
    required this.shade,
    required this.child,
  });

  final double angle; // radians, negative = folding up/away
  final double shade; // 0..1 darkness overlay

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final transform = Matrix4.identity()
      ..setEntry(3, 2, 0.0018) // perspective depth
      ..rotateX(angle);

    return Transform(
      alignment: Alignment.topCenter,
      transform: transform,
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(shade),
                    Colors.black.withOpacity(shade * 0.35),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
