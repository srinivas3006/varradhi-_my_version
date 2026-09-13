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
          _dynamicTitle ?? 'నిబంధనలు మరియు షరతులు',
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
              _buildSectionHeader(_dynamicTitle ?? 'నిబంధనలు మరియు షరతులు', isDark),
              if (_updatedAt != null) ...[
                const SizedBox(height: 6),
                Text(
                  'చివరిగా అప్‌డేట్ చేసిన తేదీ: ${_updatedAt!.day}/${_updatedAt!.month}/${_updatedAt!.year}',
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
              _buildSectionHeader('నిబంధనలు మరియు షరతులు', isDark),
              const SizedBox(height: 12),
              _buildParagraph(
                'వారధికి స్వాగతం. మా మొబైల్ అప్లికేషన్ మరియు సేవలను ఉపయోగించడం ద్వారా, మీరు ఈ సేవా నిబంధనలకు కట్టుబడి ఉండటానికి అంగీకరిస్తున్నారు.',
                isDark,
              ),
              _buildParagraph(
                '1. వినియోగదారు అర్హత: ప్లాట్‌ఫారమ్‌ను ఉపయోగించడానికి కనీసం 13 సంవత్సరాల వయస్సు ఉండాలి. మీ ఖాతా వివరాల గోప్యతను కాపాడటం మీ బాధ్యత.',
                isDark,
              ),
              _buildParagraph(
                '2. యూజర్ కంటెంట్: కథనాలు, వ్యాఖ్యలు లేదా మీడియాను సమర్పించేటప్పుడు, ఆ సమాచారాన్ని ప్రచురించే మరియు పంపిణీ చేసే హక్కును మీరు వారధికి అందిస్తున్నారు.',
                isDark,
              ),
              _buildParagraph(
                '3. రిపోర్టర్ బాధ్యతలు: సిటిజెన్ రిపోర్టర్లు ఖచ్చితమైన, వాస్తవ సమాచారాన్ని మాత్రమే అందించాలి. అసత్యమైన, ఇతరులను కించపరిచే లేదా కాపీరైట్ ఉల్లంఘించే కంటెంట్‌ను పోస్ట్ చేస్తే రిపోర్టర్ హోదా రద్దు చేయబడుతుంది.',
                isDark,
              ),
              _buildParagraph(
                '4. రివార్డులు మరియు చెల్లింపులు: ఆమోదించబడిన కథనాల ద్వారా వచ్చే రివార్డ్ టోకెన్‌లను నిర్దేశిత నిబంధనలు మరియు కనీస బ్యాలెన్స్ పరిమితికి లోబడి విత్‌డ్రా చేసుకోవచ్చు.',
                isDark,
              ),
              _buildParagraph(
                '5. బాధ్యత పరిమితి: పౌరులు అందించే నివేదికలలోని సమాచార లోపాలకు వారధి బాధ్యత వహించదు.',
                isDark,
              ),
            ],
            const SizedBox(height: 40),
            Center(
              child: Text(
                '© 2026 వారధి మీడియా. సర్వ హక్కులు ప్రత్యేకించబడ్డాయి.',
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
