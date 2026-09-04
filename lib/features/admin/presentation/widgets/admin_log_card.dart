import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../data/models/admin_moderation_log_model.dart';
import '../theme/admin_colors.dart';

class StatusTransitionChip extends StatelessWidget {
  final String oldStatus;
  final String newStatus;
  const StatusTransitionChip({super.key, required this.oldStatus, required this.newStatus});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (oldStatus.isNotEmpty) ...[
          Text(oldStatus, style: TextStyle(color: AdminColors.textSecondaryColor(isDark), fontSize: 11)),
          const SizedBox(width: 4),
          Icon(Icons.arrow_forward, size: 12, color: AdminColors.textSecondaryColor(isDark)),
          const SizedBox(width: 4),
        ],
        Text(newStatus, style: const TextStyle(color: AdminColors.primary, fontSize: 11, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class AdminLogCard extends StatelessWidget {
  final AdminModerationLogModel log;
  const AdminLogCard({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.card(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.cardBorder(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AdminColors.accentSecondary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: Text(log.action, style: const TextStyle(color: AdminColors.accentSecondary, fontSize: 10, fontWeight: FontWeight.w800)),
              ),
              const Spacer(),
              Text(timeago.format(log.createdAt), style: TextStyle(color: AdminColors.textSecondaryColor(isDark), fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),
          Text(log.submissionTitle, style: TextStyle(color: AdminColors.textPrimary(isDark), fontWeight: FontWeight.w700, fontSize: 14)),
          if (log.oldStatus.isNotEmpty || log.newStatus.isNotEmpty) ...[
            const SizedBox(height: 6),
            StatusTransitionChip(oldStatus: log.oldStatus, newStatus: log.newStatus),
          ],
          if (log.notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(log.notes, style: TextStyle(color: AdminColors.textSecondaryColor(isDark), fontSize: 12.5)),
          ],
          if (log.adminEmail.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(log.adminEmail, style: TextStyle(color: AdminColors.textSecondaryColor(isDark), fontSize: 11.5, fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }
}
