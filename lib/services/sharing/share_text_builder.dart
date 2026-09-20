import 'share_models.dart';

/// The text that accompanies every share.
///
/// Kept apart from the transport so the wording is asserted directly in
/// tests, and so no screen invents its own phrasing.
class ShareTextBuilder {
  const ShareTextBuilder._();

  /// Body for a link share. Shape is:
  ///
  ///   {title}
  ///
  ///   {canonical url}
  ///
  ///   Shared via {app}
  ///
  /// Polls and videos get their own lead-in, since "vote here" and "watch"
  /// tell the reader what the link is for.
  static String forContent(ShareContent content) {
    final url = content.canonicalUrl;
    if (url == null || url.isEmpty) return content.title.trim();

    // Lead-in per type, so the reader knows what the link is for.
    final lead = switch (content.contentType) {
      ShareContentType.article => 'Read on Vaaradhi News:',
      ShareContentType.video ||
      ShareContentType.short =>
        'Watch on Vaaradhi News:',
      ShareContentType.poster => 'Shared from Vaaradhi News:',
      ShareContentType.poll => 'Vote on Vaaradhi News:',
      ShareContentType.ugc => 'Community news on Vaaradhi News:',
    };

    final buffer = StringBuffer();
    if (content.title.trim().isNotEmpty) {
      buffer
        ..writeln(content.title.trim())
        ..writeln();
    }
    buffer
      ..writeln(lead)
      // The canonical public page. The backend renders Open Graph metadata
      // there, which is what gives WhatsApp and the rest their preview.
      ..write(url);
    return buffer.toString();
  }

  /// Caption for a media share. The link still travels with the file so the
  /// recipient can reach the full item.
  static String forMedia(ShareContent content, ShareFormat format) {
    final prefix = format == ShareFormat.video ? '[VIDEO]\n\n' : '';
    return '$prefix${forContent(content)}';
  }
}
