import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool _isLoading = true;
  String? _dynamicTitle;
  String? _dynamicContent;
  DateTime? _updatedAt;

  @override
  void initState() {
    super.initState();
    _loadTerms();
  }

  Future<void> _loadTerms() async {
    setState(() => _isLoading = true);
    try {
      final cms = await ApiService.instance.getCmsPage('terms') ??
          await ApiService.instance.getCmsPage('terms-and-conditions');

      if (!mounted) return;
      if (cms != null && cms['content'] != null) {
        setState(() {
          _dynamicTitle = cms['title']?.toString();
          _dynamicContent = _cleanHtml(cms['content'].toString());
          if (cms['updated_at'] != null) {
            _updatedAt = DateTime.tryParse(cms['updated_at'].toString());
          }
          _isLoading = false;
        });
        return;
      }
    } catch (_) {
      // Gracefully fall back to local content
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  String _cleanHtml(String html) {
    return html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'</li>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<li>', caseSensitive: false), '• ')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.white70 : Colors.black87;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _dynamicTitle ?? 'Terms of Service',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        foregroundColor: textColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadTerms,
        color: AppColors.primary,
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_dynamicContent != null && _dynamicContent!.isNotEmpty) ...[
              _buildSectionHeader(_dynamicTitle ?? 'Terms & Conditions', isDark),
              if (_updatedAt != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Last updated: ${_updatedAt!.day}/${_updatedAt!.month}/${_updatedAt!.year}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                _dynamicContent!,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.6,
                  color: secondaryTextColor,
                ),
              ),
            ] else ...[
              _buildSectionHeader('Terms of Service', isDark),
              const SizedBox(height: 12),
              _buildParagraph(
                'Welcome to Vaaradhi. By accessing or using our mobile application and services, you agree to be bound by these Terms of Service.',
                isDark,
              ),
              _buildParagraph(
                '1. User Eligibility: You must be at least 13 years old to use the platform. As a registered user, you are responsible for maintaining the confidentiality of your account credentials.',
                isDark,
              ),
              _buildParagraph(
                '2. User-Generated Content: When submitting articles, comments, or multimedia content, you grant Vaaradhi a worldwide, royalty-free license to distribute and display your content.',
                isDark,
              ),
              _buildParagraph(
                '3. Reporter Responsibilities: Citizen reporters must provide truthful, authentic information. Submitting false, defamatory, or copyright-infringing content will result in termination of reporter status.',
                isDark,
              ),
              _buildParagraph(
                '4. Rewards & Redemptions: Reward tokens accrued through approved articles are redeemable according to our payout schedule and minimum balance thresholds.',
                isDark,
              ),
              _buildParagraph(
                '5. Limitation of Liability: Vaaradhi does not guarantee continuous, uninterrupted access to our services and disclaims liability for inaccuracies in citizen-reported news.',
                isDark,
              ),
            ],
            const SizedBox(height: 40),
            Center(
              child: Text(
                '© 2026 Vaaradhi Media. All rights reserved.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : Colors.black87,
      ),
    );
  }

  Widget _buildParagraph(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          height: 1.5,
          color: isDark ? Colors.white70 : Colors.black87,
        ),
      ),
    );
  }
}
