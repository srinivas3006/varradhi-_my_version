import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Privacy & Policies', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
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
          _buildParagraph('• Content must be factually accurate and objective.'),
          _buildParagraph('• No hate speech, harassment, or inciteful language.'),
          _buildParagraph('• All media (photos/videos) must be original or appropriately licensed.'),
          _buildParagraph('Violations of these policies will result in post rejection and potential suspension from the Reporter Program.'),
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
