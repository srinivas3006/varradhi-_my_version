import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../localization/app_translations.dart';
import '../localization/location_translations.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = [
    (icon: Icons.home_rounded, key: 'nav_home'),
    // Main and Local open the full-screen Spotlight feed as its own route
    // rather than switching tabs, so they never show as selected.
    (icon: Icons.auto_awesome_rounded, key: 'nav_main_news'),
    // Index 2 is the centre slot the floating Post button occupies — the
    // Row renders a gap here and the label below comes from _items[2], so
    // nothing else may take this position.
    (icon: Icons.add, key: 'nav_post'),
    (icon: Icons.play_circle_outline_rounded, key: 'nav_reels'),
    // Local opens the local Spotlight feed and is labelled with the
    // reader's own place (see _localLabel). Profile lives in the Home
    // header now, top-left.
    (icon: Icons.location_on_rounded, key: 'nav_local'),
  ];

  /// The reader's nearest named place for the Local tab — village, then
  /// mandal, district, city — or the plain "Local" label when none is set.
  /// In Telugu, the place's Telugu name (from the location API, else the
  /// built-in table); a name neither knows stays as it is.
  static String _localLabel() {
    final s = AppState.instance;
    for (final place in [s.village, s.subdistrict, s.district, s.city]) {
      if (place.trim().isNotEmpty) {
        return s.showsTeluguPlaceNames
            ? LocationTranslations.toTelugu(place)
            : place.trim();
      }
    }
    return tr('nav_local');
  }

  /// How far the floating Post button rises above the bar.
  static const double _postRise = 20;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? AppColors.cardDarkSlate.withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.9);

    return AnimatedBuilder(
      // AppState too, so the Local tab's place name follows a location
      // change.
      animation: Listenable.merge(
          [AppState.instance.themeAndLocaleNotifier, AppState.instance]),
      builder: (context, _) {
        final postLabel = tr(_items[2].key);

        // The Post button rises _postRise above the bar. Flutter only
        // delivers taps inside a widget's own bounds, so when the button hung
        // outside the Stack its upper part silently ignored taps. The Stack
        // now includes that strip; its empty sides have no child and let
        // taps through to the page behind.
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: _postRise),
              child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: bgColor,
                    border: Border(
                      top: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                  child: SafeArea(
                    child: SizedBox(
                      height: 65,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: List.generate(_items.length, (index) {
                          if (index == 2) {
                            return const SizedBox(width: 64);
                          }

                          final item = _items[index];
                          final isActive = index == currentIndex;
                          final itemLabel = item.key == 'nav_local'
                              ? _localLabel()
                              : tr(item.key);

                          return Expanded(
                            child: Semantics(
                              button: true,
                              selected: isActive,
                              label: itemLabel,
                              child: Tooltip(
                                message: itemLabel,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    onTap(index);
                                  },
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      AnimatedScale(
                                        scale: isActive ? 1.15 : 1.0,
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeOutBack,
                                        child: Icon(
                                          item.icon,
                                          size: 24,
                                          color: isActive
                                              ? AppColors.primary
                                              : AppColors.textMuted,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 2),
                                        child: Text(
                                          itemLabel,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight:
                                                isActive ? FontWeight.w700 : FontWeight.w500,
                                            color: isActive
                                                ? AppColors.primary
                                                : AppColors.textMuted,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ),
            Positioned(
              top: 0,
              child: Semantics(
                button: true,
                selected: currentIndex == 2,
                label: postLabel,
                child: Tooltip(
                  message: postLabel,
                  child: GestureDetector(
                    key: const Key('nav_post_button'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onTap(2);
                    },
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: isDark ? AppColors.cardDarkSlate : Colors.white,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
