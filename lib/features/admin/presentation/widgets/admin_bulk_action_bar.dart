import 'package:flutter/material.dart';
import '../theme/admin_colors.dart';

class AdminBulkActionBar extends StatelessWidget {
  final int selectedCount;
  final int totalCount;
  final bool isSubmitting;
  final VoidCallback onSelectAll;
  final VoidCallback onDeselectAll;
  final ValueChanged<String> onAction;

  const AdminBulkActionBar({
    super.key,
    required this.selectedCount,
    required this.totalCount,
    required this.isSubmitting,
    required this.onSelectAll,
    required this.onDeselectAll,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allSelected = selectedCount > 0 && selectedCount == totalCount;

    return Material(
      color: AdminColors.card(isDark),
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  TextButton(
                    onPressed: allSelected ? onDeselectAll : onSelectAll,
                    child: Text(allSelected ? 'Deselect' : 'Select All'),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AdminColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                    child: Text('$selectedCount selected', style: const TextStyle(color: AdminColors.primary, fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                  const Spacer(),
                  if (isSubmitting) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _actionButton(context, 'Approve', Icons.check_circle_outline, AdminColors.success, 'approve'),
                  const SizedBox(width: 6),
                  _actionButton(context, 'Reject', Icons.cancel_outlined, AdminColors.error, 'reject'),
                  const SizedBox(width: 6),
                  _actionButton(context, 'Flag', Icons.flag_outlined, AdminColors.warning, 'flag'),
                  const SizedBox(width: 6),
                  _actionButton(context, 'Trust+', Icons.trending_up, AdminColors.accentSecondary, 'increase_trust'),
                  const SizedBox(width: 6),
                  _actionButton(context, 'Block', Icons.block, AdminColors.error, 'block'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton(BuildContext context, String label, IconData icon, Color color, String action) {
    return Expanded(
      child: OutlinedButton(
        onPressed: (selectedCount == 0 || isSubmitting) ? null : () => onAction(action),
        style: OutlinedButton.styleFrom(foregroundColor: color, side: BorderSide(color: color), padding: const EdgeInsets.symmetric(vertical: 10)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
