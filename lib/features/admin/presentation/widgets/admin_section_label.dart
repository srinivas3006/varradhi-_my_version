import 'package:flutter/material.dart';
import '../theme/admin_colors.dart';

/// 11px/700-weight/0.8-letterspacing colored section label, reused by
/// detail-screen cards and dialogs.
class AdminSectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const AdminSectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          text.toUpperCase(),
          style: const TextStyle(color: AdminColors.primary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
