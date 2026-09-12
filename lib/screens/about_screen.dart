import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  bool _isLoading = true;
  String? _dynamicTitle;
  String? _dynamicContent;

  @override
  void initState() {
    super.initState();
    _loadAbout();
  }

  Future<void> _loadAbout() async {
    setState(() => _isLoading = true);
    try {
      final cms = await ApiService.instance.getCmsPage('about');
      if (!mounted) return;
      if (cms != null && cms['content'] != null) {
        setState(() {
          _dynamicTitle = cms['title']?.toString();
          _dynamicContent = _cleanHtml(cms['content'].toString());
          _isLoading = false;
        });
        return;
      }
    } catch (_) {
      // Fall back to local content
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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_dynamicTitle ?? 'About Vaaradhi', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        foregroundColor: textColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadAbout,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // Logo
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 80,
                  height: 80,
                  errorBuilder: (_, __, ___) => Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.language_rounded, size: 60, color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Vaaradhi',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your Local News Bridge',
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white54 : Colors.black54,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 32),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: CircularProgressIndicator(),
                )
              else if (_dynamicContent != null && _dynamicContent!.isNotEmpty)
                _buildInfoCard(
                  context,
                  _dynamicTitle ?? 'About Us',
                  _dynamicContent!,
                  isDark,
                )
              else ...[
                _buildInfoCard(
                  context, 
                  'Our Story', 
                  'Vaaradhi started with a simple idea: local news matters. We wanted to build a platform that bridges the gap between communities and the information that affects their daily lives, directly from the ground up.',
                  isDark,
                ),
                const SizedBox(height: 20),
                _buildInfoCard(
                  context, 
                  'Our Goal', 
                  'To empower citizen journalists and provide a transparent, hyper-local news ecosystem where everyone has a voice. Through the Reporter Program, we reward users who actively contribute authentic, verified news to their district.',
                  isDark,
                ),
              ],
              const SizedBox(height: 40),
              Text(
                'Version 1.0.0',
                style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '© 2026 Vaaradhi Media. All rights reserved.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, String title, String content, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black87,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
