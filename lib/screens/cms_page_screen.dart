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
          _error = 'సమాచారాన్ని లోడ్ చేయడం విఫలమైంది.';
          _isLoading = false;
        });
      }
    }
  }

  String _getDefaultContent(String slug) {
    switch (slug.toLowerCase()) {
      case 'about':
        return 'వారధి ఆంధ్రప్రదేశ్ మరియు తెలంగాణ అంతటా విశ్వసనీయమైన, నిజ-సమయ స్థానిక వార్తలు మరియు సమాచారాన్ని అందించే ప్రముఖ వేదిక.\n\nపారదర్శకమైన సమాచారంతో పౌరులకు అండగా నిలవడం, సిటిజెన్ జర్నలిజం ద్వారా స్థానిక గళాన్ని వినిపించడం మా లక్ష్యం.';
      case 'contact':
        return 'మీకు ఏవైనా ప్రశ్నలు, అభిప్రాయాలు లేదా ప్రకటనల విచారణలు ఉన్నాయా?\n\nఇమెయిల్: contact@vaaradhinews.com\nఫోన్: +91 98765 43210\nచిరునామా: వారధి మీడియా నెట్‌వర్క్, హైదరాబాద్, తెలంగాణ, భారతదేశం.';
      case 'privacy':
      case 'privacy-policy':
        return 'మీ గోప్యత మాకు చాలా ముఖ్యం. మీ వ్యక్తిగత సమాచారం మరియు ప్రాధాన్యతలు సురక్షితంగా రక్షించబడతాయి. మేము మీ వ్యక్తిగత వివరాలను ఎవరికీ విక్రయించము.';
      case 'terms':
      case 'terms-and-conditions':
        return 'వారధిని ఉపయోగించడం ద్వారా, మీరు మా సేవా నిబంధనలకు కట్టుబడి ఉంటారు. పౌర జర్నలిజం ద్వారా వార్తలను పోస్ట్ చేసే వినియోగదారులు ఆ సమాచార వాస్తవికతకు బాధ్యత వహించాలి.';
      default:
        return 'సమాచారం త్వరలో అందుబాటులోకి వస్తుంది.';
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
          _title ?? 'సమాచారం',
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
              child: const Text('మళ్లీ ప్రయత్నించండి'),
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
