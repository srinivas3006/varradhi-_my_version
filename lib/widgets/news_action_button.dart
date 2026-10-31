import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Which action a [NewsActionButton] is: decides its colour and its tap
/// animation (pastel action-button design, Oct 2026).
enum NewsAction { like, dislike, comment, download, share, more }

/// Colours per action: the icon / ring colour and the pastel behind it.
class NewsActionPalette {
  const NewsActionPalette(this.primary, this.pastel);
  final Color primary;
  final Color pastel;

  static const like = NewsActionPalette(Color(0xFFFF1744), Color(0xFFFFE4EA));
  static const dislike =
      NewsActionPalette(Color(0xFF1685FF), Color(0xFFE3F0FF));
  static const comment =
      NewsActionPalette(Color(0xFF1685FF), Color(0xFFE3F0FF));
  static const download =
      NewsActionPalette(Color(0xFF00B85A), Color(0xFFDDF8E9));
  /// Red #FF0000.
  static const share = NewsActionPalette(Color(0xFFFF0000), Color(0xFFFFE5E5));
  static const more = NewsActionPalette(Color(0xFF455A64), Color(0xFFECEFF1));

  static NewsActionPalette of(NewsAction a) => switch (a) {
        NewsAction.like => like,
        NewsAction.dislike => dislike,
        NewsAction.comment => comment,
        NewsAction.download => download,
        NewsAction.share => share,
        NewsAction.more => more,
      };
}

/// An article action (like, dislike, comment, download, share, more) with
/// its tap animation: a press, a spring back, a ripple ring, and — when the
/// button becomes active (liked, disliked, downloaded) — a small particle
/// burst. Nothing glows or floats at rest.
///
/// Only the look is here. [onTap] is the screen's existing handler, called
/// at once (the animation never delays it); [isActive] is the screen's
/// state, so the burst plays only when the action really took effect — a
/// like the backend rejected and rolled back shows no burst.
class NewsActionButton extends StatefulWidget {
  const NewsActionButton({
    super.key,
    required this.action,
    required this.icon,
    required this.onTap,
    this.isActive = false,
    this.label = '',
    this.idleColor,
    this.diameter = 40,
    this.iconSize = 22,
    this.filled = false,
    this.guardWhileBusy = false,
    this.semanticLabel,
    this.slot = 48,
    this.inline = false,
    this.ringed = false,
    this.labelColor,
  });

  final NewsAction action;
  final IconData icon;

  /// The screen's handler. With [guardWhileBusy], taps are ignored until a
  /// returned Future completes (no overlapping like/dislike requests).
  final FutureOr<void> Function() onTap;
  final bool isActive;

  /// Count or caption under the icon; changes slide in.
  final String label;

  /// Icon colour while a like / dislike is not active.
  final Color? idleColor;
  final double diameter;
  final double iconSize;

  /// A solid circle with a white icon (the prominent Share).
  final bool filled;
  final bool guardWhileBusy;
  final String? semanticLabel;

  /// Height kept for the count under the icon, whether or not there is one.
  static const labelHeight = 14.0;

  /// Size of the square the circle sits in: 48 (minimum touch target) by
  /// default. A bar that gives each action a full-width cell, like the
  /// 58 px article bar, may pass less to fit its height with the label.
  final double slot;

  /// Bar style (white action strip): the count sits beside the icon in a
  /// fixed-width box, icons are plain grey at rest, and only an active like
  /// / dislike shows its pastel circle.
  final bool inline;

  /// A white ring around a [filled] circle (the raised Share).
  final bool ringed;

  /// Overrides the caption colour (e.g. the grey "Share" under the circle).
  final Color? labelColor;

  /// Width kept for an inline count ("1.2k" fits), so a count changing never
  /// nudges the buttons beside it.
  static const inlineCountWidth = 30.0;

  /// Like and dislike are toggles: neutral until active.
  bool get isToggle =>
      action == NewsAction.like || action == NewsAction.dislike;

  @override
  State<NewsActionButton> createState() => _NewsActionButtonState();
}

class _NewsActionButtonState extends State<NewsActionButton>
    with TickerProviderStateMixin {
  /// Press, spring and ripple: one run per tap.
  late final AnimationController _tap = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420));

  /// Particles: one run per activation.
  late final AnimationController _burst = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 650));

  bool _busy = false;

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.85)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 19), // ~80 ms press
    TweenSequenceItem(
        tween: Tween(begin: 0.85, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 33), // ~140 ms spring
    TweenSequenceItem(
        tween: Tween(begin: 1.2, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 48),
  ]).animate(_tap);

  /// Ripple starts ~100 ms in and fades by the end.
  late final Animation<double> _ripple = CurvedAnimation(
      parent: _tap, curve: const Interval(0.22, 1, curve: Curves.easeOut));

  bool get _reduceMotion => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void didUpdateWidget(covariant NewsActionButton old) {
    super.didUpdateWidget(old);
    final activated = widget.isActive && !old.isActive;
    if (activated &&
        (widget.isToggle || widget.action == NewsAction.download) &&
        !_reduceMotion) {
      _burst.forward(from: 0);
    }
  }

  Future<void> _handleTap() async {
    if (_busy) return;
    if (!_reduceMotion) _tap.forward(from: 0);
    // Comment / share / more give a small burst on every tap.
    if (!_reduceMotion &&
        (widget.action == NewsAction.comment ||
            widget.action == NewsAction.share)) {
      _burst.forward(from: 0);
    }
    final result = widget.onTap();
    if (widget.guardWhileBusy && result is Future) {
      _busy = true;
      try {
        await result;
      } catch (_) {
        // The handler reports its own errors; the guard only times taps.
      } finally {
        _busy = false;
      }
    }
  }

  @override
  void dispose() {
    _tap.dispose();
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = NewsActionPalette.of(widget.action);
    final idle = widget.idleColor ??
        (isDark ? const Color(0xFF9AA4B2) : const Color(0xFF6B7280));

    // Toggles are neutral until active; the other actions always carry
    // their pastel circle. Share is a solid circle.
    final showCircle = widget.filled ||
        (widget.inline ? widget.isActive : !widget.isToggle || widget.isActive);
    final quiet = widget.inline
        ? !widget.isActive
        : widget.isToggle && !widget.isActive;
    final iconColor = widget.filled
        ? Colors.white
        : quiet
            ? idle
            : palette.primary;
    final circleColor = widget.filled
        ? palette.primary
        : isDark
            ? palette.primary.withValues(alpha: 0.18)
            : palette.pastel;
    final labelColor = widget.labelColor ??
        (quiet || widget.filled ? idle : palette.primary);

    final d = widget.diameter;
    // A 48 px slot (minimum touch target). The ring and particles reach a
    // little past it without taking layout space, so six buttons still fit
    // a 320 px-wide phone.
    final box = math.max(widget.slot, d + 2);
    final effects = box + 16;

    final iconWidget = AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
      child: Icon(widget.icon,
          key: ValueKey(widget.icon), color: iconColor, size: widget.iconSize),
    );

    final button = SizedBox(
      width: box,
      height: box,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Ripple ring + particles: only while animating.
          Positioned.fill(
            child: IgnorePointer(
              child: OverflowBox(
                maxWidth: effects,
                maxHeight: effects,
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: Size.square(effects),
                    painter: _EffectsPainter(
                      tap: _ripple,
                      burst: _burst,
                      color: palette.primary,
                      hearts: widget.action == NewsAction.like,
                      innerRadius: d / 2,
                    ),
                  ),
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _tap,
            builder: (context, child) {
              final turns = widget.action == NewsAction.more
                  ? math.sin(_tap.value * math.pi) * 0.06
                  : 0.0;
              return Transform.rotate(
                angle: turns * 2 * math.pi,
                child: Transform.scale(
                    scale: _tap.isAnimating ? _scale.value : 1, child: child),
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              width: d,
              height: d,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: showCircle ? circleColor : Colors.transparent,
                border: widget.ringed
                    ? Border.all(
                        color: isDark ? const Color(0xFF1B2333) : Colors.white,
                        width: 4)
                    : null,
                boxShadow: widget.filled
                    ? [
                        BoxShadow(
                          color: palette.primary.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: iconWidget,
            ),
          ),
        ],
      ),
    );

    final count = AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      layoutBuilder: (current, previous) => Stack(
        alignment:
            widget.inline ? Alignment.centerLeft : Alignment.center,
        children: [...previous, if (current != null) current],
      ),
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.5), end: Offset.zero)
              .animate(a),
          child: child,
        ),
      ),
      child: Text(
        widget.label,
        key: ValueKey(widget.label),
        maxLines: 1,
        overflow: TextOverflow.clip,
        softWrap: false,
        textScaler: TextScaler.noScaling,
        style: TextStyle(
            color: labelColor,
            fontSize: widget.inline ? 14 : 11.5,
            fontWeight: widget.inline ? FontWeight.w500 : FontWeight.w600,
            height: 1.1),
      ),
    );

    if (widget.inline) {
      return Semantics(
        button: true,
        label: widget.semanticLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _handleTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              button,
              // Like / dislike always keep their count box: a tap can make
              // the count appear, and that must not shift the bar. Others
              // (comment, download %) take room only when they have one.
              if (widget.label.isNotEmpty || widget.isToggle)
                SizedBox(
                  width: NewsActionButton.inlineCountWidth,
                  height: 20,
                  child: ClipRect(child: count),
                ),
            ],
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            button,
            // The count line is always reserved, filled or not: a count
            // appearing (0 -> 1 like) or changing never changes the
            // button's height, so the bar never shifts up and down.
            SizedBox(
              height: NewsActionButton.labelHeight,
              child: ClipRect(child: count),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ripple ring and a few particles, drawn only while their animations run.
class _EffectsPainter extends CustomPainter {
  _EffectsPainter({
    required this.tap,
    required this.burst,
    required this.color,
    required this.hearts,
    required this.innerRadius,
  }) : super(repaint: Listenable.merge([tap, burst]));

  final Animation<double> tap;
  final Animation<double> burst;
  final Color color;
  final bool hearts;
  final double innerRadius;

  static const _particles = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final maxR = size.shortestSide / 2;

    final t = tap.value;
    if (t > 0 && t < 1) {
      final r = innerRadius + (maxR - innerRadius) * t;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: 0.45 * (1 - t)),
      );
    }

    final b = burst.value;
    if (b > 0 && b < 1) {
      final fade = (1 - b).clamp(0.0, 1.0);
      final dist = innerRadius * 0.7 + (maxR - innerRadius * 0.7 - 3) * b;
      final paint = Paint()..color = color.withValues(alpha: 0.85 * fade);
      for (var i = 0; i < _particles; i++) {
        final angle = (i / _particles) * 2 * math.pi - math.pi / 2 + b * 0.6;
        final p = c + Offset(math.cos(angle), math.sin(angle)) * dist;
        final s = (hearts ? 4.2 : 2.6) * (1 - b * 0.4);
        if (hearts) {
          _heart(canvas, p, s, paint, angle);
        } else {
          canvas.drawCircle(p, s, paint);
        }
      }
    }
  }

  static void _heart(Canvas canvas, Offset at, double s, Paint p, double rot) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(rot * 0.3);
    final path = Path()
      ..moveTo(0, s * 0.9)
      ..cubicTo(-s * 1.6, -s * 0.2, -s * 0.6, -s * 1.4, 0, -s * 0.5)
      ..cubicTo(s * 0.6, -s * 1.4, s * 1.6, -s * 0.2, 0, s * 0.9)
      ..close();
    canvas.drawPath(path, p);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EffectsPainter old) =>
      old.color != color || old.hearts != hearts;
}
