import 'package:flutter/material.dart';

/// Centres its child while the page has room for it, and scrolls only when it
/// genuinely does not fit.
///
/// This exists because of a specific way to get it wrong. A page inside a
/// vertical `PageView` that wraps its content in a `SingleChildScrollView`
/// sized from `MediaQuery.sizeOf(context).height` is always a few pixels
/// taller than its own viewport — the status-bar inset and the page's padding
/// are not part of that number. Those few pixels give the inner scroll view a
/// real scroll extent, and a vertical scrollable inside a vertical pager wins
/// the drag: the reader swipes up, the card twitches, and the feed refuses to
/// advance past that one card.
///
/// Measuring the viewport with a [LayoutBuilder] instead means the extent is
/// exactly zero whenever the content fits, so the swipe belongs to the pager
/// — and the content still scrolls on the small screens where it must.
class FitOrScroll extends StatelessWidget {
  const FitOrScroll({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });

  final Widget child;
  final EdgeInsets padding;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxHeight.isFinite
            ? (constraints.maxHeight - padding.vertical).clamp(0.0, 1e6)
            : 0.0;

        return SingleChildScrollView(
          padding: padding,
          // Clamping matters: with no extent to scroll it declines the drag
          // outright, and the pager gets it.
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: available),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: crossAxisAlignment,
              mainAxisSize: MainAxisSize.min,
              children: [child],
            ),
          ),
        );
      },
    );
  }
}
