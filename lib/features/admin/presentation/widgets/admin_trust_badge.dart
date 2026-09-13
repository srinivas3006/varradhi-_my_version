import 'package:flutter/material.dart';
import '../../data/models/admin_ugc_status.dart';
import '../theme/admin_colors.dart';

class AdminTrustBadge extends StatelessWidget {
  final AdminTrustLevel level;
  const AdminTrustBadge({super.key, required this.level});

  Color _colorFor(AdminTrustLevel level) {
    switch (level) {
      case AdminTrustLevel.newUser:
        return AdminColors.textSecondary;
      case AdminTrustLevel.trustedReporter:
        return AdminColors.accentSecondary;
      case AdminTrustLevel.adminReporter:
        return AdminColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        level.teluguLabel,
        style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}
