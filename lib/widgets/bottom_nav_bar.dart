import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../localization/app_translations.dart';
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
    (icon: Icons.location_on_rounded, key: 'nav_local'),
    (icon: Icons.add, key: 'nav_post'),
    (icon: Icons.play_circle_fill_rounded, key: 'nav_video'),
    (icon: Icons.person_rounded, key: 'nav_profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? AppColors.cardDarkSlate.withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.9);

    return AnimatedBuilder(
      animation: AppState.instance.themeAndLocaleNotifier,
      builder: (context, _) {
        final postLabel = tr(_items[2].key);

        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            ClipRRect(
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
                            return const SizedBox(width: 70);
                          }

                          final item = _items[index];
                          final isActive = index == currentIndex;
                          final itemLabel =
                              (index == 1 && AppState.instance.displayLocation.isNotEmpty)
                                  ? AppState.instance.displayLocation
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
            Positioned(
              top: -20,
              child: Semantics(
                button: true,
                selected: currentIndex == 2,
                label: postLabel,
                child: Tooltip(
                  message: postLabel,
                  child: GestureDetector(
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
