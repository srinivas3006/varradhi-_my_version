import 'package:flutter/material.dart';
import '../theme/admin_colors.dart';

class AdminFilterChipOption<T> {
  final T value;
  final String label;
  const AdminFilterChipOption(this.value, this.label);
}

/// Generic reusable FilterChip row driven by a (value,label) list — reused
/// by all 4 tabs' status rows and the queue's refinement row.
class AdminFilterChipRow<T> extends StatelessWidget {
  final List<AdminFilterChipOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelect;

  const AdminFilterChipRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final option = options[index];
          final isSelected = option.value == selected;
          return ChoiceChip(
            label: Text(option.label),
            selected: isSelected,
            onSelected: (_) => onSelect(option.value),
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : AdminColors.textSecondaryColor(isDark),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
            selectedColor: AdminColors.primary,
            backgroundColor: AdminColors.surface(isDark),
            side: BorderSide(color: isSelected ? AdminColors.primary : AdminColors.cardBorder(isDark)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          );
        },
      ),
    );
  }
}
