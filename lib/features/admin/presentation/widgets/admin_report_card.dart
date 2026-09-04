import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../data/models/admin_report_model.dart';
import '../theme/admin_colors.dart';

class AdminReportCard extends StatelessWidget {
  final AdminReportModel report;
  final VoidCallback onDismiss;
  final VoidCallback onMarkReviewed;

  const AdminReportCard({super.key, required this.report, required this.onDismiss, required this.onMarkReviewed});

  Color _statusColor() {
    switch (report.status) {
      case 'REVIEWED':
        return AdminColors.success;
      case 'DISMISSED':
        return AdminColors.textSecondary;
      default:
        return AdminColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _statusColor();

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
              _pill(report.status, color),
              const SizedBox(width: 6),
              _pill(report.reasonLabel, AdminColors.accentSecondary),
              const Spacer(),
              Text(timeago.format(report.createdAt), style: TextStyle(color: AdminColors.textSecondaryColor(isDark), fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),
          Text(report.targetSubmissionTitle, style: TextStyle(color: AdminColors.textPrimary(isDark), fontWeight: FontWeight.w700, fontSize: 14)),
          if (report.reporterNote.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(report.reporterNote, style: TextStyle(color: AdminColors.textSecondaryColor(isDark), fontSize: 12.5)),
          ],
          if (report.reporterEmail.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(report.reporterEmail, style: TextStyle(color: AdminColors.textSecondaryColor(isDark), fontSize: 11.5)),
          ],
          if (report.status == 'PENDING') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Spacer(),
                OutlinedButton(onPressed: onDismiss, child: const Text('Dismiss')),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: onMarkReviewed,
                  style: ElevatedButton.styleFrom(backgroundColor: AdminColors.success, foregroundColor: Colors.white),
                  child: const Text('Mark Reviewed'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
      child: Text(text.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }
}
