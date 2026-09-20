import 'package:flutter/material.dart';

import '../../services/sharing/content_share_service.dart';
import '../../services/sharing/share_brand_config.dart';
import '../../services/sharing/share_models.dart';
import '../../theme/app_theme.dart';

/// The one share sheet every Share button opens.
///
/// Offers only the formats the item actually supports, so a text-only article
/// never shows a dead "Video" button.
class ShareSheet extends StatefulWidget {
  const ShareSheet({super.key, required this.content});

  final ShareContent content;

  static Future<void> show(BuildContext context, ShareContent content) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareSheet(content: content),
    );
  }

  @override
  State<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<ShareSheet> {
  ShareFormat? _busy;

  Future<void> _run(ShareFormat format) async {
    if (_busy != null) return;
    setState(() => _busy = format);

    final messenger = ScaffoldMessenger.of(context);
    final result =
        await ContentShareService.share(widget.content, format: format);
    if (!mounted) return;
    setState(() => _busy = null);

    // Cancelling is a normal thing to do and must never read as an error.
    if (result == ShareResult.shared || result == ShareResult.cancelled) {
      if (result == ShareResult.shared) Navigator.of(context).maybePop();
      return;
    }

    messenger
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(result == ShareResult.unavailable
            ? 'This item cannot be shared.'
            : 'Could not share. Please try again.'),
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<void> _copy() async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await ContentShareService.copyLink(widget.content);
    if (!mounted) return;
    Navigator.of(context).maybePop();
    messenger
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(result == ShareResult.shared
            ? 'Link copied'
            : 'Nothing to copy'),
        behavior: SnackBarBehavior.floating,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formats = widget.content.availableFormats;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Share',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              widget.content.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            const SizedBox(height: 18),
            Text('Share as',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white54 : Colors.black54,
                )),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final f in formats) ...[
                  Expanded(child: _formatButton(f, isDark)),
                  if (f != formats.last) const SizedBox(width: 10),
                ],
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.link_rounded, size: 20),
              title: const Text('Copy link', style: TextStyle(fontSize: 14)),
              onTap: _copy,
            ),
            Text(
              ShareBrandConfig.displayDomain,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formatButton(ShareFormat format, bool isDark) {
    final busy = _busy == format;
    final (icon, label) = switch (format) {
      ShareFormat.link => (Icons.public_rounded, 'Link'),
      ShareFormat.image => (Icons.image_rounded, 'Image'),
      ShareFormat.video => (Icons.play_circle_outline_rounded, 'Video'),
    };

    return OutlinedButton(
      onPressed: _busy == null ? () => _run(format) : null,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        foregroundColor: AppColors.primary,
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2))
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20),
                const SizedBox(height: 4),
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
    );
  }
}
