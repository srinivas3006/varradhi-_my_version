import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'auth/auth_ui.dart' show authBackground, authMuted, authTitle;

/// A content page in the app's branded style: a red gradient header (logo
/// or icon tile, title, subtitle) that collapses into a solid red app bar as
/// the reader scrolls, then white section cards.
///
/// Used by About, Privacy, Terms and the reporter intro so they match the
/// login and sign-up screens.
class BrandedPage extends StatefulWidget {
  const BrandedPage({
    super.key,
    required this.barTitle,
    required this.title,
    this.subtitle,
    required this.children,
    this.icon,
    this.actions,
    this.onRefresh,
    this.bottom,
  });

  /// Shown in the app bar once the header has scrolled away.
  final String barTitle;
  final String title;
  final String? subtitle;

  /// Shown in the white tile; the logo when null.
  final IconData? icon;
  final List<Widget> children;
  final List<Widget>? actions;
  final Future<void> Function()? onRefresh;

  /// Pinned below the content (e.g. a call-to-action button).
  final Widget? bottom;

  static const double expandedHeight = 300;

  @override
  State<BrandedPage> createState() => _BrandedPageState();
}

class _BrandedPageState extends State<BrandedPage> {
  final _scroll = ScrollController();
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final collapsed = _scroll.hasClients &&
          _scroll.offset > BrandedPage.expandedHeight - 140;
      if (collapsed != _collapsed) setState(() => _collapsed = collapsed);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget scroll = CustomScrollView(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: BrandedPage.expandedHeight,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 2,
          centerTitle: false,
          actions: widget.actions,
          title: AnimatedOpacity(
            opacity: _collapsed ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: Text(
              widget.barTitle,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.parallax,
            background: _Header(
              title: widget.title,
              subtitle: widget.subtitle,
              icon: widget.icon,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          sliver: SliverList(
            delegate: SliverChildListDelegate(widget.children),
          ),
        ),
      ],
    );

    if (widget.onRefresh != null) {
      scroll = RefreshIndicator(
        onRefresh: widget.onRefresh!,
        color: AppColors.primary,
        edgeOffset: BrandedPage.expandedHeight,
        child: scroll,
      );
    }

    return Scaffold(
      backgroundColor: authBackground(context),
      body: scroll,
      bottomNavigationBar: widget.bottom == null
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.cardDarkNavy
                    : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(top: false, child: widget.bottom!),
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, this.subtitle, this.icon});

  final String title;
  final String? subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, Color(0xFFC81B00)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, MediaQuery.of(context).padding.top + kToolbarHeight, 24, 26),
      alignment: Alignment.bottomCenter,
      // Scales down rather than overflowing if a long title wraps.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: MediaQuery.of(context).size.width - 48,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: icon != null
                    ? Icon(icon, color: AppColors.primary, size: 38)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.asset('assets/images/logo.png',
                            fit: BoxFit.contain),
                      ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  height: 1.25,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13.5,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A white rounded card with an optional icon + title row.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    this.icon,
    this.title,
    required this.child,
  });

  final IconData? icon;
  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDarkNavy : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: isDark ? AppColors.borderDark : const Color(0xFFEDEDF0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    title!,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: authTitle(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

/// Body text inside a [SectionCard].
class DocText extends StatelessWidget {
  const DocText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14.5,
          height: 1.6,
          color:
              isDark ? AppColors.readingBodyDark : AppColors.readingBodyLight,
        ),
      ),
    );
  }
}

/// A numbered clause: red number badge, bold heading, body.
///
/// [DocClause.parse] turns "2. Heading: body" into one, so existing copy
/// keeps its wording.
class DocClause extends StatelessWidget {
  const DocClause({
    super.key,
    required this.number,
    required this.heading,
    required this.body,
  });

  final String number;
  final String heading;
  final String body;

  static Widget parse(String text) {
    final m = RegExp(r'^\s*(\d+)\.\s*([^:]+):\s*(.+)$', dotAll: true)
        .firstMatch(text);
    if (m == null) return DocText(text);
    return DocClause(
        number: m.group(1)!, heading: m.group(2)!.trim(), body: m.group(3)!);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  heading,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: authTitle(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.55,
                    color: isDark
                        ? AppColors.readingBodyDark
                        : AppColors.readingBodyLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A bullet line with a red check.
class DocBullet extends StatelessWidget {
  const DocBullet(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.check_circle_rounded,
                size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                height: 1.55,
                color: isDark
                    ? AppColors.readingBodyDark
                    : AppColors.readingBodyLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Last updated" pill shown under a CMS document.
class DocUpdated extends StatelessWidget {
  const DocUpdated(this.date, {super.key});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(Icons.update_rounded, size: 16, color: authMuted(context)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'చివరిగా అప్‌డేట్ చేసిన తేదీ: ${date.day}/${date.month}/${date.year}',
              style: TextStyle(fontSize: 12.5, color: authMuted(context)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Copyright line at the foot of a document page.
class DocFooter extends StatelessWidget {
  const DocFooter({super.key, this.extra});

  final String? extra;

  @override
  Widget build(BuildContext context) {
    final muted = authMuted(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          if (extra != null) ...[
            Text(extra!,
                style: TextStyle(
                    color: muted, fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
          ],
          Text(
            '© 2026 వారధి మీడియా. సర్వ హక్కులు ప్రత్యేకించబడ్డాయి.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ],
      ),
    );
  }
}
