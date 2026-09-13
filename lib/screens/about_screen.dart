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
        title: Text(_dynamicTitle ?? 'వారధి గురించి', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                'వారధి',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'మీ స్థానిక వార్తా వారధి',
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
                  _dynamicTitle ?? 'వారధి గురించి',
                  _dynamicContent!,
                  isDark,
                )
              else ...[
                _buildInfoCard(
                  context, 
                  'మా కథ', 
                  'స్థానిక వార్తలకు అత్యంత ప్రాధాన్యత ఉందనే ఆలోచనతో వారధి ప్రారంభమైంది. ప్రజల దైనందిన జీవితాలను ప్రభావితం చేసే స్థానిక సమాచారాన్ని ప్రజల వద్దకు నేరుగా చేర్చే వారధిగా నిలవడమే మా లక్ష్యం.',
                  isDark,
                ),
                const SizedBox(height: 20),
                _buildInfoCard(
                  context, 
                  'మా లక్ష్యం', 
                  'పౌర జర్నలిస్టులను ప్రోత్సహించడం మరియు పారదర్శకమైన, విశ్వసనీయమైన స్థానిక వార్తా వేదికను అందించడం. సిటిజెన్ రిపోర్టర్ ప్రోగ్రామ్ ద్వారా తమ జిల్లా వార్తలను అందించే ప్రతి ఒక్కరికీ తగిన ప్రోత్సాహకాలు అందించబడతాయి.',
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
                '© 2026 వారధి మీడియా. సర్వ హక్కులు ప్రత్యేకించబడ్డాయి.',
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
