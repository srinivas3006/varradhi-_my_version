import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onTrailingTap;
  final String? trailingText;
  final bool compact;

  const SectionHeader({
    super.key,
    required this.title,
    this.onTrailingTap,
    this.trailingText,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: compact ? 8 : 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          if (onTrailingTap != null && trailingText != null)
            TextButton(
              onPressed: onTrailingTap,
              style: TextButton.styleFrom(
                visualDensity: compact ? VisualDensity.compact : null,
              ),
              child: Text(
                trailingText!,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
