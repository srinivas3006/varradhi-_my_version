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
    (icon: Icons.add_box_rounded, key: 'nav_post'),
    (icon: Icons.play_circle_fill_rounded, key: 'nav_video'),
    (icon: Icons.person_rounded, key: 'nav_profile'),
  ];

  @override
  Widget build(BuildContext context) {
    // Listens to AppState so labels update the moment the language changes,
    // even though this bar stays mounted across the whole app session.
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: SizedBox(
              height: 58,
              child: Row(
                children: List.generate(_items.length, (index) {
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
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        );
      },
    );
  }
}
