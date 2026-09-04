import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../data/models/admin_ugc_submission_model.dart';
import '../theme/admin_colors.dart';
import 'admin_video_preview.dart';

class AdminMediaViewer extends StatefulWidget {
  final AdminUgcSubmissionModel submission;
  final VoidCallback? onUploadBranded;

  const AdminMediaViewer({super.key, required this.submission, this.onUploadBranded});

  @override
  State<AdminMediaViewer> createState() => _AdminMediaViewerState();
}

class _AdminMediaViewerState extends State<AdminMediaViewer> {
  bool _showBranded = false;
  bool _playingVideo = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = widget.submission;
    final showingUrl = _showBranded && s.hasBrandedMedia ? s.brandedMediaUrl : s.originalMediaUrl;
    final showingType = _showBranded && s.hasBrandedMedia ? s.brandedMediaType : s.originalMediaType;
    final isVideo = showingType.toLowerCase() == 'video';

    return Container(
      decoration: BoxDecoration(
        color: AdminColors.card(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.cardBorder(isDark)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Original Media'),
                      selected: !_showBranded,
                      onSelected: (_) => setState(() => _showBranded = false),
                    ),
                    if (s.hasBrandedMedia)
                      ChoiceChip(
                        label: const Text('VARADHI Branded ✓'),
                        selected: _showBranded,
                        onSelected: (_) => setState(() => _showBranded = true),
                        selectedColor: AdminColors.success.withValues(alpha: 0.2),
                      ),
                  ],
                ),
              ),
              if (widget.onUploadBranded != null)
                TextButton.icon(
                  onPressed: widget.onUploadBranded,
                  icon: const Icon(Icons.verified_outlined, size: 18, color: AdminColors.primary),
                  label: const Text('Upload Branded', style: TextStyle(color: AdminColors.primary, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                color: Colors.black12,
                child: _buildMediaBody(showingUrl, isVideo),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (s.uploadStatus.isNotEmpty) _buildStatusChip('Upload: ${s.uploadStatus}', isDark),
              if (s.validationStatus.isNotEmpty) _buildStatusChip('Validation: ${s.validationStatus}', isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMediaBody(String url, bool isVideo) {
    if (url.isEmpty) {
      return const Center(
        child: Text('No media', style: TextStyle(color: Colors.white70)),
      );
    }
    if (isVideo) {
      if (_playingVideo) return AdminVideoPreview(videoUrl: url);
      return GestureDetector(
        onTap: () => setState(() => _playingVideo = true),
        child: Stack(
          alignment: Alignment.center,
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: widget.submission.videoThumbnailUrl.isNotEmpty ? widget.submission.videoThumbnailUrl : url,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(color: Colors.black26),
            ),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
            ),
          ],
        ),
      );
    }
    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.contain,
        errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white54)),
      ),
    );
  }

  Widget _buildStatusChip(String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AdminColors.surface(isDark),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminColors.cardBorder(isDark)),
      ),
      child: Text(label, style: TextStyle(color: AdminColors.textSecondaryColor(isDark), fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
