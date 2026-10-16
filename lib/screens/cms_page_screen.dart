import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/cms_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/auth/auth_ui.dart' show AuthPrimaryButton, authMuted;
import '../widgets/branded_page.dart';
import '../widgets/cms_contact_actions.dart';

/// A backend-managed page (About, Privacy, Terms, Contact …).
///
/// Everything shown comes from GET /api/v1/cms/{slug}/: the title and the
/// HTML body. Nothing about the page is written into the app; [fallbackTitle]
/// is only the menu label, used in the header until the page arrives.
///
/// The last good copy is kept on the device: it shows at once while the page
/// refreshes, and stands in when the network or server fails.
class CMSPageScreen extends StatefulWidget {
  const CMSPageScreen({
    super.key,
    required this.slug,
    this.initialTitle,
    this.service,
  });

  final String slug;

  /// The menu label (e.g. "Privacy Policy") shown until the page loads.
  final String? initialTitle;

  @visibleForTesting
  final CmsService? service;

  @override
  State<CMSPageScreen> createState() => _CMSPageScreenState();
}

class _CMSPageScreenState extends State<CMSPageScreen> {
  CmsService get _service => widget.service ?? CmsService.instance;

  CmsPage? _page;
  CmsStatus? _status;
  bool _loading = true;

  bool get _telugu => AppState.instance.language == 'Telugu';

  @override
  void initState() {
    super.initState();
    _showCachedThenRefresh();
  }

  Future<void> _showCachedThenRefresh() async {
    final saved = await _service.cached(widget.slug);
    if (!mounted) return;
    if (saved != null && _page == null) {
      setState(() {
        _page = saved;
        _status = CmsStatus.cached;
      });
    }
    await _refresh();
  }

  Future<void> _refresh() async {
    if (mounted) setState(() => _loading = true);
    final result = await _service.load(widget.slug);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _status = result.status;
      // A missing page drops any earlier copy; a failure keeps what is shown.
      if (result.page != null || result.status == CmsStatus.notFound) {
        _page = result.page;
      }
    });
  }

  IconData? get _icon => switch (widget.slug) {
        CmsSlugs.about => null, // the logo
        CmsSlugs.privacy => Icons.shield_outlined,
        CmsSlugs.terms => Icons.gavel_rounded,
        CmsSlugs.contact => Icons.support_agent_rounded,
        _ => Icons.article_outlined,
      };

  String get _title {
    final t = _page?.title ?? '';
    if (t.isNotEmpty) return t;
    return widget.initialTitle ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return BrandedPage(
      barTitle: _title,
      title: _title,
      icon: _icon,
      onRefresh: _refresh,
      children: [_buildBody(context)],
    );
  }

  Widget _buildBody(BuildContext context) {
    final page = _page;

    if (page == null) {
      if (_loading) {
        return const Padding(
          key: Key('cms_loading'),
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        );
      }
      final missing = _status == CmsStatus.notFound;
      return _StatePanel(
        key: Key(missing ? 'cms_not_found' : 'cms_failed'),
        icon: missing ? Icons.find_in_page_outlined : Icons.wifi_off_rounded,
        message: missing
            ? (_telugu ? 'పేజీ అందుబాటులో లేదు' : 'Page not available')
            : (_telugu
                ? 'పేజీని లోడ్ చేయలేకపోయాం. ఇంటర్నెట్ కనెక్షన్ చూసి మళ్లీ ప్రయత్నించండి.'
                : 'Could not load this page. Check your connection and try again.'),
        retryLabel: _telugu ? 'మళ్లీ ప్రయత్నించండి' : 'Retry',
        onRetry: _refresh,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_status == CmsStatus.cached && !_loading) _buildOfflineNote(),
        // Contact Us: the email / phone / website the page itself lists, as
        // tap buttons above the text (Play News policy: clearly visible).
        if (widget.slug == CmsSlugs.contact)
          CmsContactActions(html: page.content),
        SectionCard(
          key: const Key('cms_content'),
          child: _CmsHtml(html: _withoutRepeatedTitle(page)),
        ),
      ],
    );
  }

  Widget _buildOfflineNote() {
    return Container(
      key: const Key('cms_offline_note'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 18, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _telugu
                  ? 'ఆఫ్‌లైన్ — చివరిగా సేవ్ చేసిన కాపీ'
                  : 'Offline — showing the last saved copy',
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
          TextButton(
            onPressed: _refresh,
            child: Text(_telugu ? 'రిఫ్రెష్' : 'Refresh'),
          ),
        ],
      ),
    );
  }

  /// The body often opens with an <h1> of the same title the header already
  /// shows; drop that one heading so it is not printed twice.
  String _withoutRepeatedTitle(CmsPage page) {
    final m =
        RegExp(r'^\s*<h1[^>]*>(.*?)</h1>', caseSensitive: false, dotAll: true)
            .firstMatch(page.content);
    if (m == null) return page.content;
    final heading =
        m.group(1)!.replaceAll(RegExp(r'<[^>]*>'), '').trim().toLowerCase();
    if (heading.isEmpty || heading != page.title.trim().toLowerCase()) {
      return page.content;
    }
    return page.content.substring(m.end);
  }
}

/// Renders CMS HTML natively — no WebView and no scripts — in the app's
/// reading style. Links open outside the app (mailto:/tel: included).
class _CmsHtml extends StatelessWidget {
  const _CmsHtml({required this.html});

  final String html;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final body =
        isDark ? AppColors.readingBodyDark : AppColors.readingBodyLight;
    final heading = isDark ? AppColors.readingTitleDark : AppColors.textDark;
    String hex(Color c) =>
        '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

    return HtmlWidget(
      html,
      textStyle: TextStyle(fontSize: 15, height: 1.6, color: body),
      customStylesBuilder: (e) {
        switch (e.localName) {
          case 'h1':
            return {
              'font-size': '21px',
              'font-weight': '800',
              'color': hex(heading),
              'margin': '4px 0 10px 0',
            };
          case 'h2':
            return {
              'font-size': '18px',
              'font-weight': '800',
              'color': hex(heading),
              'margin': '16px 0 8px 0',
            };
          case 'h3':
          case 'h4':
            return {
              'font-size': '16px',
              'font-weight': '700',
              'color': hex(heading),
              'margin': '12px 0 6px 0',
            };
          case 'p':
            return {'margin': '0 0 12px 0'};
          case 'a':
            return {
              'color': hex(AppColors.primary),
              'font-weight': '600',
            };
          case 'li':
            return {'margin': '0 0 6px 0'};
        }
        return null;
      },
      onTapUrl: (url) async {
        final uri = Uri.tryParse(url);
        if (uri == null) return false;
        return launchUrl(uri, mode: LaunchMode.externalApplication);
      },
    );
  }
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({
    super.key,
    required this.icon,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final IconData icon;
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 15, height: 1.5, color: authMuted(context)),
            ),
            const SizedBox(height: 20),
            AuthPrimaryButton(
              key: const Key('cms_retry'),
              label: retryLabel,
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
