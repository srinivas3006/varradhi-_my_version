import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../data/models/admin_ugc_status.dart';
import '../../data/models/admin_ugc_submission_model.dart';
import '../theme/admin_colors.dart';
import 'admin_status_badge.dart';
import 'admin_trust_badge.dart';

class AdminUgcCard extends StatelessWidget {
  final AdminUgcSubmissionModel item;
  final bool multiSelectMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onToggleSelected;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onFlag;
  final VoidCallback onViewProfile;
  final VoidCallback onIncreaseTrust;
  final VoidCallback onDecreaseTrust;
  final VoidCallback onToggleBlock;

  const AdminUgcCard({
    super.key,
    required this.item,
    required this.multiSelectMode,
    required this.selected,
    required this.onTap,
    required this.onToggleSelected,
    required this.onApprove,
    required this.onReject,
    required this.onFlag,
    required this.onViewProfile,
    required this.onIncreaseTrust,
    required this.onDecreaseTrust,
    required this.onToggleBlock,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: multiSelectMode ? onToggleSelected : onTap,
      onLongPress: onToggleSelected,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AdminColors.card(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AdminColors.primary : AdminColors.cardBorder(isDark), width: selected ? 1.5 : 1),
          boxShadow: isDark
              ? []
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (multiSelectMode) ...[
                  Checkbox(value: selected, onChanged: (_) => onToggleSelected()),
                  const SizedBox(width: 4),
                ],
                AdminStatusBadge(status: item.status),
                const SizedBox(width: 6),
                AdminTrustBadge(level: item.trustLevel),
                if (item.uploaderBlocked) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AdminColors.error.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                    child: const Text('BLOCKED', style: TextStyle(color: AdminColors.error, fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                ],
                const Spacer(),
                Text(
                  timeago.format(item.submittedAt),
                  style: TextStyle(color: AdminColors.textSecondaryColor(isDark), fontSize: 11),
                ),
                if (!multiSelectMode)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, size: 20, color: AdminColors.textSecondaryColor(isDark)),
                    onSelected: (value) {
                      switch (value) {
                        case 'profile':
                          onViewProfile();
                          break;
                        case 'increase_trust':
                          onIncreaseTrust();
                          break;
                        case 'decrease_trust':
                          onDecreaseTrust();
                          break;
                        case 'toggle_block':
                          onToggleBlock();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'profile', child: Text('View Reporter Profile')),
                      if (item.status != AdminUgcStatus.approved) ...[
                        const PopupMenuItem(value: 'increase_trust', child: Text('Increase Trust')),
                        const PopupMenuItem(value: 'decrease_trust', child: Text('Decrease Trust')),
                      ],
                      PopupMenuItem(value: 'toggle_block', child: Text(item.uploaderBlocked ? 'Unblock Uploader' : 'Block Uploader')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 68,
                    height: 68,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        item.hasMedia
                            ? CachedNetworkImage(
                                imageUrl: item.isVideo && item.videoThumbnailUrl.isNotEmpty ? item.videoThumbnailUrl : item.originalMediaUrl,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(color: Colors.black12),
                              )
                            : Container(color: Colors.black12, child: const Icon(Icons.image_not_supported_outlined, color: Colors.white38)),
                        if (item.isVideo)
                          const Center(
                            child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 24),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AdminColors.textPrimary(isDark), fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 13, color: AdminColors.textSecondaryColor(isDark)),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              '${item.district}, ${item.stateName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: AdminColors.textSecondaryColor(isDark), fontSize: 11.5),
                            ),
                          ),
                        ],
                      ),
                      if (item.reporterMobile.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.phone_outlined, size: 12, color: AdminColors.textSecondaryColor(isDark)),
                            const SizedBox(width: 2),
                            Text(item.reporterMobile, style: TextStyle(color: AdminColors.textSecondaryColor(isDark), fontSize: 11.5)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (item.duplicateFlagged || item.reportCount > 0) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: AdminColors.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 15, color: AdminColors.warning),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        [
                          if (item.duplicateFlagged) 'Duplicate ${item.duplicateScore?.toStringAsFixed(0) ?? '?'}%',
                          if (item.reportCount > 0) '${item.reportCount} user reports',
                        ].join('  •  '),
                        style: const TextStyle(color: AdminColors.warning, fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Divider(height: 1, color: AdminColors.cardBorder(isDark)),
            const SizedBox(height: 8),
            _buildActionRow(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRow(bool isDark) {
    if (item.status.isPendingLike) {
      return Row(
        children: [
          IconButton(
            onPressed: onFlag,
            icon: const Icon(Icons.flag_outlined, color: AdminColors.warning, size: 20),
            tooltip: 'Flag',
          ),
          const Spacer(),
          OutlinedButton(
            onPressed: onReject,
            style: OutlinedButton.styleFrom(foregroundColor: AdminColors.error, side: const BorderSide(color: AdminColors.error)),
            child: const Text('Reject'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onApprove,
            style: ElevatedButton.styleFrom(backgroundColor: AdminColors.success, foregroundColor: Colors.white),
            child: const Text('Approve'),
          ),
        ],
      );
    }
    if (item.status == AdminUgcStatus.flagged) {
      return Row(
        children: [
          TextButton(onPressed: onViewProfile, child: const Text('Profile')),
          const Spacer(),
          OutlinedButton(
            onPressed: onReject,
            style: OutlinedButton.styleFrom(foregroundColor: AdminColors.error, side: const BorderSide(color: AdminColors.error)),
            child: const Text('Reject'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onApprove,
            style: ElevatedButton.styleFrom(backgroundColor: AdminColors.success, foregroundColor: Colors.white),
            child: const Text('Approve'),
          ),
        ],
      );
    }
    // approved / rejected
    return Row(
      children: [
        TextButton(onPressed: onViewProfile, child: const Text('Profile')),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: item.status.color(isDark).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
          child: Text(item.status.label, style: TextStyle(color: item.status.color(isDark), fontWeight: FontWeight.w700, fontSize: 12)),
        ),
      ],
    );
  }
}
