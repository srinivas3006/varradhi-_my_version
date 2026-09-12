import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class CMSPageScreen extends StatefulWidget {
  final String slug;
  final String? initialTitle;

  const CMSPageScreen({
    super.key,
    required this.slug,
    this.initialTitle,
  });

  @override
  State<CMSPageScreen> createState() => _CMSPageScreenState();
}

class _CMSPageScreenState extends State<CMSPageScreen> {
  bool _isLoading = true;
  String? _title;
  String? _content;
  String? _error;

  @override
  void initState() {
    super.initState();
    _title = widget.initialTitle ?? _formatTitle(widget.slug);
    _loadPage();
  }

  String _formatTitle(String slug) {
    return slug
        .replaceAll('-', ' ')
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
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
        .replaceAll('&#39;', "'")
        .trim();
  }

  Future<void> _loadPage() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final cms = await ApiService.instance.getCmsPage(widget.slug);
      if (cms != null && mounted) {
        setState(() {
          if (cms['title'] != null && cms['title'].toString().isNotEmpty) {
            _title = cms['title'].toString();
          }
          if (cms['content'] != null) {
            _content = _cleanHtml(cms['content'].toString());
          }
          _isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            // Provide fallback text if CMS is not seeded
            _content = _getDefaultContent(widget.slug);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load document.';
          _isLoading = false;
        });
      }
    }
  }

  String _getDefaultContent(String slug) {
    switch (slug.toLowerCase()) {
      case 'about':
        return 'Varadhi is your trusted regional digital news and hyper-local media platform, delivering verified, realtime news, community updates, and multimedia coverage across Andhra Pradesh and Telangana.\n\nOur mission is to empower citizens with objective information and foster community voice through citizen journalism.';
      case 'contact':
        return 'Have questions, feedback, or advertising inquiries?\n\nEmail: contact@vaaradhinews.com\nPhone: +91 98765 43210\nAddress: Vaaradhi Media Network, Hyderabad, Telangana, India.';
      case 'privacy':
      case 'privacy-policy':
        return 'We value your privacy. Your personal information, location coordinates, and bookmarks are encrypted and handled strictly in accordance with our data protection guidelines. We do not sell your personal data to third parties.';
      case 'terms':
      case 'terms-and-conditions':
        return 'By using Vaaradhi, you agree to access content for personal, non-commercial use. Users posting content via Citizen Journalism are responsible for the authenticity and legality of their submissions.';
      default:
        return 'Information will be available soon.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _title ?? 'Information',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: isDark ? Colors.white38 : Colors.black38),
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPage,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _title ?? '',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 48,
              height: 3,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _content ?? '',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white70 : Colors.black87,
                height: 1.7,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
