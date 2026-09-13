import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
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
                    child: const Text('బ్లాక్ చేయబడింది', style: TextStyle(color: AdminColors.error, fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                ],
                const Spacer(),
                Text(
                  _formatTeluguTime(item.submittedAt),
                  style: TextStyle(color: AdminColors.textSecondaryColor(isDark), fontSize: 11.5, fontWeight: FontWeight.w500),
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
                      const PopupMenuItem(value: 'profile', child: Text('రిపోర్టర్ ప్రొఫైల్ చూడండి')),
                      if (item.status != AdminUgcStatus.approved) ...[
                        const PopupMenuItem(value: 'increase_trust', child: Text('విశ్వసనీయత పెంచు')),
                        const PopupMenuItem(value: 'decrease_trust', child: Text('విశ్వసనీయత తగ్గించు')),
                      ],
                      PopupMenuItem(value: 'toggle_block', child: Text(item.uploaderBlocked ? 'యూజర్‌ను అన్‌బ్లాక్ చేయి' : 'యూజర్‌ను బ్లాక్ చేయి')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [const Color(0xFF2C3240), const Color(0xFF1E222D)]
                            : [const Color(0xFFF0F4F8), const Color(0xFFE2E8F0)],
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (item.hasMedia)
                          CachedNetworkImage(
                            imageUrl: item.isVideo && item.videoThumbnailUrl.isNotEmpty ? item.videoThumbnailUrl : item.originalMediaUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: isDark ? Colors.white10 : Colors.black12,
                              child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                            ),
                            errorWidget: (_, __, ___) => _buildFallbackThumbnail(isDark),
                          )
                        else
                          _buildFallbackThumbnail(isDark),
                        if (item.isVideo)
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.5)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            child: const Center(
                              child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 28),
                            ),
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
                        style: TextStyle(color: AdminColors.textPrimary(isDark), fontSize: 14.5, fontWeight: FontWeight.w700, height: 1.3),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 14, color: AdminColors.textSecondaryColor(isDark)),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              '${item.district}, ${item.stateName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: AdminColors.textSecondaryColor(isDark), fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      if (item.reporterMobile.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(Icons.phone_outlined, size: 13, color: AdminColors.textSecondaryColor(isDark)),
                            const SizedBox(width: 3),
                            Text(item.reporterMobile, style: TextStyle(color: AdminColors.textSecondaryColor(isDark), fontSize: 12, fontWeight: FontWeight.w500)),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(color: AdminColors.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 16, color: AdminColors.warning),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        [
                          if (item.duplicateFlagged) 'డూప్లికేట్ ${item.duplicateScore?.toStringAsFixed(0) ?? '?'}%',
                          if (item.reportCount > 0) '${item.reportCount} యూజర్ ఫిర్యాదులు',
                        ].join('  •  '),
                        style: const TextStyle(color: AdminColors.warning, fontSize: 12, fontWeight: FontWeight.w700),
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

  Widget _buildFallbackThumbnail(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            item.isVideo ? Icons.videocam_outlined : Icons.newspaper_rounded,
            size: 26,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
          const SizedBox(height: 2),
          Text(
            item.isVideo ? 'వీడియో' : 'కథనం',
            style: TextStyle(fontSize: 9.5, color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  String _formatTeluguTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) {
      return '${diff.inDays} రోజుల క్రితం';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} గంటల క్రితం';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} నిమిషాల క్రితం';
    } else {
      return 'ఇప్పుడే';
    }
  }

  Widget _buildActionRow(bool isDark) {
    if (item.status.isPendingLike) {
      return Row(
        children: [
          IconButton(
            onPressed: onFlag,
            icon: const Icon(Icons.flag_outlined, color: AdminColors.warning, size: 20),
            tooltip: 'ఫ్లాగ్ చేయి',
          ),
          TextButton(
            onPressed: onViewProfile,
            child: const Text('ప్రొఫైల్', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          const Spacer(),
          OutlinedButton(
            onPressed: onReject,
            style: OutlinedButton.styleFrom(
              foregroundColor: AdminColors.error,
              side: const BorderSide(color: AdminColors.error),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: const Text('తిరస్కరించు', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onApprove,
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.success,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('ఆమోదించు', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      );
    }
    if (item.status == AdminUgcStatus.flagged) {
      return Row(
        children: [
          TextButton(
            onPressed: onViewProfile,
            child: const Text('ప్రొఫైల్', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          const Spacer(),
          OutlinedButton(
            onPressed: onReject,
            style: OutlinedButton.styleFrom(
              foregroundColor: AdminColors.error,
              side: const BorderSide(color: AdminColors.error),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('తిరస్కరించు', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onApprove,
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.success,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('ఆమోదించు', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      );
    }
    // Already approved or rejected: Provide re-evaluation option alongside status
    return Row(
      children: [
        TextButton(
          onPressed: onViewProfile,
          child: const Text('ప్రొఫైల్', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        const Spacer(),
        if (item.status == AdminUgcStatus.approved)
          OutlinedButton(
            onPressed: onReject,
            style: OutlinedButton.styleFrom(
              foregroundColor: AdminColors.error,
              side: BorderSide(color: AdminColors.error.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('తిరస్కరించు', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          )
        else if (item.status == AdminUgcStatus.rejected)
          OutlinedButton(
            onPressed: onApprove,
            style: OutlinedButton.styleFrom(
              foregroundColor: AdminColors.success,
              side: BorderSide(color: AdminColors.success.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('తిరిగి ఆమోదించు', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: item.status.color(isDark).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
          child: Text(
            item.status.teluguLabel,
            style: TextStyle(color: item.status.color(isDark), fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
