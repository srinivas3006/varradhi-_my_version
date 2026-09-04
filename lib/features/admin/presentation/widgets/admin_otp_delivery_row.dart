import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../data/models/admin_otp_delivery_model.dart';
import '../theme/admin_colors.dart';

class AdminOtpDeliveryRow extends StatelessWidget {
  final AdminOtpDeliveryModel delivery;
  const AdminOtpDeliveryRow({super.key, required this.delivery});

  Color _statusColor() {
    switch (delivery.status) {
      case 'DELIVERED':
      case 'SENT':
        return AdminColors.success;
      case 'FAILED':
      case 'EXPIRED':
        return AdminColors.error;
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
      child: Row(
        children: [
          Icon(Icons.sms_outlined, color: AdminColors.textSecondaryColor(isDark), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(delivery.mobile, style: TextStyle(color: AdminColors.textPrimary(isDark), fontWeight: FontWeight.w700, fontSize: 14)),
                    if (delivery.provider.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AdminColors.surface(isDark), borderRadius: BorderRadius.circular(6)),
                        child: Text(delivery.provider, style: TextStyle(color: AdminColors.textSecondaryColor(isDark), fontSize: 10)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(timeago.format(delivery.createdAt), style: TextStyle(color: AdminColors.textSecondaryColor(isDark), fontSize: 11)),
                if (delivery.failureReason.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(delivery.failureReason, style: const TextStyle(color: AdminColors.error, fontSize: 11.5)),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: Text(delivery.status, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
