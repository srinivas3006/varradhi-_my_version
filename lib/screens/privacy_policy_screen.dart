import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  bool _isLoading = true;
  String? _dynamicTitle;
  String? _dynamicContent;
  DateTime? _updatedAt;

  @override
  void initState() {
    super.initState();
    _loadPolicy();
  }

  Future<void> _loadPolicy() async {
    setState(() => _isLoading = true);
    try {
      final cms = await ApiService.instance.getCmsPage('privacy-policy') ??
          await ApiService.instance.getCmsPage('privacy');

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
          _dynamicTitle ?? 'Privacy & Policies',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        foregroundColor: textColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadPolicy,
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
              _buildSectionHeader(_dynamicTitle ?? 'Privacy Policy', isDark),
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
              const SizedBox(height: 32),
            ] else ...[
              _buildSectionHeader('Privacy Policy', isDark),
              const SizedBox(height: 12),
              _buildParagraph(
                'At Vaaradhi, we take your privacy seriously. This policy describes what personal information we collect and how we use it.',
                isDark,
              ),
              _buildParagraph(
                '1. Information Collection: We collect information you provide directly to us when you register, such as your name, phone number, and location preferences.',
                isDark,
              ),
              _buildParagraph(
                '2. Location Data: We use your location to provide hyper-local news. This data is only collected with your explicit consent and is never shared with third-party advertisers.',
                isDark,
              ),
              _buildParagraph(
                '3. Data Security: We implement industry-standard security measures to protect your personal information from unauthorized access.',
                isDark,
              ),
              const SizedBox(height: 32),
              _buildSectionHeader('Content Policies', isDark),
              const SizedBox(height: 12),
              _buildParagraph(
                'All content submitted via the Reporter Program must adhere to the following guidelines:',
                isDark,
              ),
              _buildParagraph('• Content must be factually accurate and objective.', isDark),
              _buildParagraph('• No hate speech, harassment, or inciteful language.', isDark),
              _buildParagraph('• All media (photos/videos) must be original or appropriately licensed.', isDark),
              _buildParagraph('Violations of these policies will result in post rejection and potential suspension from the Reporter Program.', isDark),
              const SizedBox(height: 32),
            ],
          const SizedBox(height: 32),
          _buildSectionHeader('Frequently Asked Questions', isDark),
          const SizedBox(height: 16),
          _buildFaqItem(
            context,
            'How do I become a Reporter?',
            'Anyone can join! Go to your Profile, tap "Join" on the Reporter card, and verify your phone number via OTP to start submitting local news.',
            isDark,
          ),
          _buildFaqItem(
            context,
            'How do I earn tokens?',
            'Once you are a reporter, submit news. For every post that our admin desk approves and publishes, you earn 1 token (₹5).',
            isDark,
          ),
          _buildFaqItem(
            context,
            'When can I withdraw my earnings?',
            'You can request a withdrawal to your UPI ID once you have accumulated 100 tokens (₹500).',
            isDark,
          ),
          _buildFaqItem(
            context,
            'Why was my post rejected?',
            'Posts are typically rejected if they violate our content policies, lack sufficient context, or if the media quality is too low to publish.',
            isDark,
          ),
          const SizedBox(height: 40),
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

  Widget _buildParagraph(String text, [bool isDark = true]) {
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

  Widget _buildFaqItem(BuildContext context, String question, String answer, bool isDark) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Text(
          question,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        iconColor: Colors.redAccent,
        collapsedIconColor: isDark ? Colors.white54 : Colors.black54,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 16.0),
        children: [
          Text(
            answer,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
