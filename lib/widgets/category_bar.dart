import 'package:flutter/material.dart';
import '../localization/app_translations.dart';
import '../theme/app_theme.dart';

class CategoryBar extends StatelessWidget {
  final List<String> categories;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const CategoryBar({
    super.key,
    required this.categories,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (categories[index] == '|') {
            return Container(
              width: 1.5,
              height: 24,
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.black12,
            );
          }
          final isSelected = index == selectedIndex;
          return GestureDetector(
            onTap: () => onSelected(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.chipBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                categoryLabel(categories[index]),
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textMuted,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 13.5,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
