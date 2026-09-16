import 'package:flutter/material.dart';
import '../../data/models/admin_ugc_status.dart';

class AdminStatusBadge extends StatelessWidget {
  final AdminUgcStatus status;
  const AdminStatusBadge({super.key, required this.status});

  IconData _iconFor(AdminUgcStatus status) {
    switch (status) {
      case AdminUgcStatus.approved:
        return Icons.check_circle_rounded;
      case AdminUgcStatus.rejected:
        return Icons.cancel_rounded;
      case AdminUgcStatus.flagged:
        return Icons.flag_rounded;
      case AdminUgcStatus.review:
        return Icons.visibility_rounded;
      case AdminUgcStatus.pending:
        return Icons.schedule_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = status.color(isDark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconFor(status), size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            status.teluguLabel,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.1),
          ),
        ],
      ),
    );
  }
}
