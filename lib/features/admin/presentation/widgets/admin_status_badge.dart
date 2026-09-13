import 'package:flutter/material.dart';
import '../../data/models/admin_ugc_status.dart';

class AdminStatusBadge extends StatelessWidget {
  final AdminUgcStatus status;
  const AdminStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = status.color(isDark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.teluguLabel,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.2),
      ),
    );
  }
}
