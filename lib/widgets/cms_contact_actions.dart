import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'auth/auth_ui.dart' show authMuted;
import 'branded_page.dart' show SectionCard;

/// The email addresses, phone numbers and website links found in a CMS
/// page's HTML. Nothing is written into the app: whatever the admin puts on
/// the Contact Us page is what is offered.
class CmsContacts {
  const CmsContacts({
    this.emails = const [],
    this.phones = const [],
    this.websites = const [],
  });

  final List<String> emails;
  final List<String> phones;
  final List<String> websites;

  bool get isEmpty => emails.isEmpty && phones.isEmpty && websites.isEmpty;

  static final _email =
      RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}');

  /// Indian numbers as people write them: +91 98765 43210, 98765-43210,
  /// 040 1234 5678 …, and any `tel:` link.
  static final _phone = RegExp(
      r'(?:\+?91[\s-]?)?(?:0\d{2,4}[\s-]?\d{3,4}[\s-]?\d{4}|[6-9]\d{4}[\s-]?\d{5})');
  static final _telHref = RegExp(r'''href=["']tel:([^"']+)["']''');
  static final _link = RegExp(r'''https?://[^\s"'<>]+''');

  factory CmsContacts.fromHtml(String html) {
    final text = html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&');

    final emails = <String>{};
    for (final m in _email.allMatches(html)) {
      emails.add(m.group(0)!.toLowerCase());
    }

    final phones = <String>{};
    for (final m in _telHref.allMatches(html)) {
      phones.add(m.group(1)!.trim());
    }
    for (final m in _phone.allMatches(text)) {
      final raw = m.group(0)!.trim();
      final digits = raw.replaceAll(RegExp(r'\D'), '');
      // Skip dates, years and other short numbers.
      if (digits.length >= 10) phones.add(raw);
    }

    final websites = <String>{};
    for (final m in _link.allMatches(html)) {
      var url = m.group(0)!;
      url = url.replaceAll(RegExp(r'[).,;]+$'), '');
      final host = Uri.tryParse(url)?.host ?? '';
      // Social and messaging links are not a contact on their own (Play).
      if (host.isEmpty ||
          RegExp(r'(facebook|instagram|twitter|x\.com|youtube|whatsapp|wa\.me|t\.me|telegram)')
              .hasMatch(host)) {
        continue;
      }
      websites.add(url);
    }

    // The same number written twice ("+91 98765 43210" and "9876543210").
    final uniquePhones = <String, String>{};
    for (final p in phones) {
      final digits = p.replaceAll(RegExp(r'\D'), '');
      final key =
          digits.length > 10 ? digits.substring(digits.length - 10) : digits;
      uniquePhones.putIfAbsent(key, () => p);
    }

    return CmsContacts(
      emails: emails.toList(),
      phones: uniquePhones.values.toList(),
      websites: websites.toList(),
    );
  }
}

/// Tap-to-contact buttons above the Contact Us text: email opens the mail
/// app, phone the dialer, a website the browser. Built only from what the
/// CMS page contains; shows nothing when it has no contacts.
class CmsContactActions extends StatelessWidget {
  const CmsContactActions({super.key, required this.html});

  final String html;

  bool get _telugu => AppState.instance.language == 'Telugu';

  Future<void> _open(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = CmsContacts.fromHtml(html);
    if (c.isEmpty) return const SizedBox.shrink();
    return SectionCard(
      key: const Key('cms_contact_actions'),
      icon: Icons.support_agent_rounded,
      title: _telugu ? 'త్వరిత సంప్రదింపు' : 'Quick contact',
      child: Column(
        children: [
          for (final e in c.emails)
            _Row(
              key: Key('contact_email_$e'),
              icon: Icons.mail_outline_rounded,
              label: _telugu ? 'ఇమెయిల్' : 'Email',
              value: e,
              onTap: () => _open(Uri(scheme: 'mailto', path: e)),
            ),
          for (final p in c.phones)
            _Row(
              key: Key('contact_phone_$p'),
              icon: Icons.call_outlined,
              label: _telugu ? 'ఫోన్' : 'Phone',
              value: p,
              onTap: () => _open(
                  Uri(scheme: 'tel', path: p.replaceAll(RegExp(r'[\s-]'), ''))),
            ),
          for (final w in c.websites)
            _Row(
              key: Key('contact_website_$w'),
              icon: Icons.language_rounded,
              label: _telugu ? 'వెబ్‌సైట్' : 'Website',
              value: w.replaceFirst(RegExp(r'^https?://'), ''),
              onTap: () => _open(Uri.parse(w)),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: value));
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
          content: Text('$value copied'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ));
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style:
                          TextStyle(fontSize: 12, color: authMuted(context))),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: authMuted(context)),
          ],
        ),
      ),
    );
  }
}
