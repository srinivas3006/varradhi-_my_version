import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

    final mediaUrl = item.isVideo && item.videoThumbnailUrl.isNotEmpty
        ? item.videoThumbnailUrl
        : (item.originalMediaUrl.isNotEmpty
            ? item.originalMediaUrl
            : item.brandedMediaUrl);

    return GestureDetector(
      onTap: multiSelectMode ? onToggleSelected : onTap,
      onLongPress: onToggleSelected,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AdminColors.card(isDark),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? AdminColors.primary
                : (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08)),
            width: selected ? 1.8 : 1.0,
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar: Status, Trust, Blocked, Time & More Menu
            Row(
              children: [
                if (multiSelectMode) ...[
                  Checkbox(
                    value: selected,
                    onChanged: (_) => onToggleSelected(),
                    activeColor: AdminColors.primary,
                  ),
                  const SizedBox(width: 4),
                ],
                AdminStatusBadge(status: item.status),
                const SizedBox(width: 8),
                AdminTrustBadge(level: item.trustLevel),
                if (item.uploaderBlocked) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AdminColors.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: AdminColors.error.withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      'బ్లాక్ చేయబడింది',
                      style: TextStyle(color: AdminColors.error, fontSize: 10, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  _formatTeluguTime(item.submittedAt),
                  style: TextStyle(
                    color: AdminColors.textSecondaryColor(isDark),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (!multiSelectMode)
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 200),
                    icon: Icon(Icons.more_vert, size: 20, color: AdminColors.textSecondaryColor(isDark)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                      const PopupMenuItem(
                        value: 'profile',
                        child: Row(
                          children: [
                            Icon(Icons.person_outline_rounded, size: 18),
                            SizedBox(width: 10),
                            Text('రిపోర్టర్ ప్రొఫైల్'),
                          ],
                        ),
                      ),
                      if (item.status != AdminUgcStatus.approved) ...[
                        const PopupMenuItem(
                          value: 'increase_trust',
                          child: Row(
                            children: [
                              Icon(Icons.arrow_upward_rounded, size: 18, color: AdminColors.success),
                              SizedBox(width: 10),
                              Text('విశ్వసనీయత పెంచు'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'decrease_trust',
                          child: Row(
                            children: [
                              Icon(Icons.arrow_downward_rounded, size: 18, color: AdminColors.warning),
                              SizedBox(width: 10),
                              Text('విశ్వసనీయత తగ్గించు'),
                            ],
                          ),
                        ),
                      ],
                      PopupMenuItem(
                        value: 'toggle_block',
                        child: Row(
                          children: [
                            Icon(
                              item.uploaderBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
                              size: 18,
                              color: AdminColors.error,
                            ),
                            const SizedBox(width: 10),
                            Text(item.uploaderBlocked ? 'యూజర్‌ను అన్‌బ్లాక్ చేయి' : 'యూజర్‌ను బ్లాక్ చేయి'),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Content Zone: Media Thumbnail + Story Details + Description Snippet
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail Box (86x86)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF262C36) : const Color(0xFFF1F5F9),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (mediaUrl.isNotEmpty)
                          CachedNetworkImage(
                            imageUrl: mediaUrl,
                            fit: BoxFit.cover,
                            memCacheWidth: 260,
                            memCacheHeight: 260,
                            placeholder: (_, __) => Container(
                              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                              child: const Center(
                                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                              ),
                            ),
                            errorWidget: (_, __, ___) => _buildFallbackThumbnail(isDark),
                          )
                        else
                          _buildFallbackThumbnail(isDark),
                        if (item.isVideo)
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            child: const Center(
                              child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 30),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Text Content & Snippet
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title.isNotEmpty ? item.title : 'శీర్షిక లేని వార్త',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.notoSansTelugu(
                          color: AdminColors.textPrimary(isDark),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                      if (item.description.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.description.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.notoSansTelugu(
                            color: AdminColors.textSecondaryColor(isDark).withValues(alpha: 0.9),
                            fontSize: 12.5,
                            height: 1.42,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      // Location & Reporter Meta
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (_buildLocationText().isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.location_on_rounded, size: 13, color: AdminColors.textSecondaryColor(isDark)),
                                const SizedBox(width: 3),
                                Text(
                                  _buildLocationText(),
                                  style: TextStyle(
                                    color: AdminColors.textSecondaryColor(isDark),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          if (item.reporterMobile.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.phone_outlined, size: 12, color: AdminColors.textSecondaryColor(isDark)),
                                const SizedBox(width: 3),
                                Text(
                                  item.reporterMobile,
                                  style: TextStyle(
                                    color: AdminColors.textSecondaryColor(isDark),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Duplicate & Reports Warning Bar
            if (item.duplicateFlagged || item.reportCount > 0) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: AdminColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AdminColors.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 16, color: AdminColors.warning),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        [
                          if (item.duplicateFlagged)
                            'నకిలీ హెచ్చరిక: ${item.duplicateScore?.toStringAsFixed(0) ?? '?'}% సారూప్యత',
                          if (item.reportCount > 0) '${item.reportCount} వినియోగదారుల ఫిర్యాదులు',
                        ].join('  •  '),
                        style: const TextStyle(color: AdminColors.warning, fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            Divider(height: 1, color: AdminColors.cardBorder(isDark)),
            const SizedBox(height: 8),

            // Action Row
            _buildActionRow(context, isDark),
          ],
        ),
      ),
    );
  }

  String _buildLocationText() {
    final parts = <String>[];
    if (item.village.isNotEmpty) parts.add(item.village);
    if (item.mandal.isNotEmpty && item.mandal != item.village) parts.add(item.mandal);
    if (item.district.isNotEmpty) parts.add(item.district);
    return parts.join(', ');
  }

  Widget _buildFallbackThumbnail(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF2B3240), const Color(0xFF1B202A)]
              : [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.isVideo ? Icons.videocam_rounded : Icons.article_rounded,
              size: 26,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
            const SizedBox(height: 3),
            Text(
              item.isVideo ? 'వీడియో' : 'వార్త',
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white38 : Colors.black38,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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

  Widget _buildActionRow(BuildContext context, bool isDark) {
    if (item.status.isPendingLike) {
      return Row(
        children: [
          IconButton(
            onPressed: onFlag,
            icon: const Icon(Icons.flag_outlined, color: AdminColors.warning, size: 20),
            tooltip: 'ఫ్లాగ్ చేయి',
          ),
          TextButton.icon(
            onPressed: onViewProfile,
            icon: const Icon(Icons.person_outline_rounded, size: 16),
            label: const Text('రిపోర్టర్', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: onReject,
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('తిరస్కరించు', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AdminColors.error,
              side: const BorderSide(color: AdminColors.error, width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: onApprove,
            icon: const Icon(Icons.check_rounded, size: 16),
            label: const Text('ఆమోదించు', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.success,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
          ),
        ],
      );
    }
    if (item.status == AdminUgcStatus.flagged) {
      return Row(
        children: [
          TextButton.icon(
            onPressed: onViewProfile,
            icon: const Icon(Icons.person_outline_rounded, size: 16),
            label: const Text('రిపోర్టర్', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: onReject,
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('తిరస్కరించు', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AdminColors.error,
              side: const BorderSide(color: AdminColors.error, width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: onApprove,
            icon: const Icon(Icons.check_rounded, size: 16),
            label: const Text('ఆమోదించు', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.success,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
          ),
        ],
      );
    }
    // Already approved or rejected: Provide re-evaluation option alongside status
    return Row(
      children: [
        TextButton.icon(
          onPressed: onViewProfile,
          icon: const Icon(Icons.person_outline_rounded, size: 16),
          label: const Text('రిపోర్టర్', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
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
            child: const Text('తిరస్కరించు', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
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
            child: const Text('తిరిగి ఆమోదించు', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
          ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: item.status.color(isDark).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: item.status.color(isDark).withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                item.status == AdminUgcStatus.approved ? Icons.check_circle_rounded : Icons.cancel_rounded,
                size: 14,
                color: item.status.color(isDark),
              ),
              const SizedBox(width: 4),
              Text(
                item.status.teluguLabel,
                style: TextStyle(color: item.status.color(isDark), fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
