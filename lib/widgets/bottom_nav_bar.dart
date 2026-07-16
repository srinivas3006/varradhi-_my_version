import 'dart:ui';
import 'package:flutter/material.dart';
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
        ? AppColors.cardDarkSlate.withOpacity(0.9)
        : Colors.white.withOpacity(0.9);

    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: bgColor,
                    border: Border(
                      top: BorderSide(
                        color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
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
                            return const SizedBox(width: 70); // Space for FAB
                          }
                          
                          final item = _items[index];
                          final isActive = index == currentIndex;
                          
                          return Expanded(
                            child: InkWell(
                              onTap: () => onTap(index),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    item.icon,
                                    size: 24,
                                    color: isActive ? AppColors.primary : AppColors.textMuted,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    tr(item.key),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                                      color: isActive ? AppColors.primary : AppColors.textMuted,
                                    ),
                                  ),
                                  if (isActive)
                                    Container(
                                      margin: const EdgeInsets.only(top: 2),
                                      width: 4,
                                      height: 4,
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
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
            
            // Floating Center FAB
            Positioned(
              top: -24,
              child: GestureDetector(
                onTap: () => onTap(2),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                    border: Border.all(
                      color: isDark ? AppColors.cardDarkSlate : Colors.white,
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 28,
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
