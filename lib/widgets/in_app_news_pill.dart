import 'dart:async';

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// A news push that arrives while the reader is in the app: one small line
/// at the top — title only — for a few seconds, instead of a sound, a
/// heads-up popup and a large banner over the story being read.
///
/// Tap opens the story; swipe up dismisses; a newer push replaces it.
class InAppNewsPill {
  InAppNewsPill._();

  static const visibleFor = Duration(seconds: 3);

  static OverlayEntry? _entry;
  static GlobalKey<_PillState>? _key;
  static Timer? _timer;

  /// Whether a pill is on screen.
  static bool get isShowing => _entry != null;

  /// Shows [title] over [overlay]; replaces any pill already shown.
  static void show(
    OverlayState overlay, {
    required String title,
    required VoidCallback onTap,
  }) {
    _removeNow();
    final key = GlobalKey<_PillState>();
    final entry = OverlayEntry(
      builder: (_) => _Pill(
        key: key,
        title: title,
        onTap: () {
          _removeNow();
          onTap();
        },
        onDismissed: _removeNow,
      ),
    );
    _entry = entry;
    _key = key;
    overlay.insert(entry);
    _timer = Timer(visibleFor, hide);
  }

  /// Slides the pill away.
  static void hide() {
    _timer?.cancel();
    _timer = null;
    final state = _key?.currentState;
    if (state == null) {
      _removeNow();
    } else {
      state.slideOut().whenComplete(_removeNow);
    }
  }

  static void _removeNow() {
    _timer?.cancel();
    _timer = null;
    final entry = _entry;
    _entry = null;
    _key = null;
    if (entry != null && entry.mounted) entry.remove();
  }
}

class _Pill extends StatefulWidget {
  const _Pill({
    super.key,
    required this.title,
    required this.onTap,
    required this.onDismissed,
  });

  final String title;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  @override
  State<_Pill> createState() => _PillState();
}

class _PillState extends State<_Pill> with SingleTickerProviderStateMixin {
  late final AnimationController _slide = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 220));

  @override
  void initState() {
    super.initState();
    _slide.forward();
  }

  Future<void> slideOut() =>
      mounted ? _slide.reverse() : Future<void>.value();

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final telugu = AppState.instance.language == 'Telugu';
    final top = MediaQuery.paddingOf(context).top + 8;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) _slide.value = 1;

    return Positioned(
      top: top,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, -1.4), end: Offset.zero)
            .animate(CurvedAnimation(parent: _slide, curve: Curves.easeOut)),
        child: Dismissible(
          key: const ValueKey('in_app_news_pill_swipe'),
          direction: DismissDirection.up,
          onDismissed: (_) => widget.onDismissed(),
          child: Material(
            key: const Key('in_app_news_pill'),
            color: const Color(0xF2202124),
            elevation: 6,
            shadowColor: Colors.black45,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active_rounded,
                        color: AppColors.primary, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      telugu ? 'చూడండి' : 'Open',
                      style: const TextStyle(
                        color: Color(0xFFFF8A65),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
