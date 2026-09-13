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
          _dynamicTitle ?? 'గోప్యతా విధానం & నిబంధనలు',
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
              _buildSectionHeader(_dynamicTitle ?? 'గోప్యతా విధానం', isDark),
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
              const SizedBox(height: 32),
            ] else ...[
              _buildSectionHeader('గోప్యతా విధానం', isDark),
              const SizedBox(height: 12),
              _buildParagraph(
                'వారధిలో మీ గోప్యతకు మేము అత్యంత విలువనిస్తాము. మేము సేకరించే సమాచారం మరియు దాన్ని ఎలా ఉపయోగిస్తామో ఈ విధానం వివరిస్తుంది.',
                isDark,
              ),
              _buildParagraph(
                '1. సమాచార సేకరణ: మీరు నమోదు చేసుకున్నప్పుడు అందించే పేరు, ఫోన్ నంబర్ మరియు లొకేషన్ ప్రాధాన్యతలు వంటి సమాచారాన్ని మేము సేకరిస్తాము.',
                isDark,
              ),
              _buildParagraph(
                '2. లొకేషన్ సమాచారం: స్థానిక వార్తలను మీకు అందించడానికి మీ లొకేషన్‌ను ఉపయోగిస్తాము. ఇది మీ స్పష్టమైన అనుమతితో మాత్రమే సేకరించబడుతుంది మరియు ప్రకటనదారులకు ఎప్పుడూ షేర్ చేయబడదు.',
                isDark,
              ),
              _buildParagraph(
                '3. డేటా భద్రత: మీ వ్యక్తిగత సమాచార భద్రత కోసం పరిశ్రమ స్థాయి భద్రతా ప్రమాణాలను మేము అమలు చేస్తాము.',
                isDark,
              ),
              const SizedBox(height: 32),
              _buildSectionHeader('కంటెంట్ విధానాలు', isDark),
              const SizedBox(height: 12),
              _buildParagraph(
                'రిపోర్టర్ ప్రోగ్రామ్ ద్వారా సమర్పించే ప్రతి కంటెంట్ క్రింది నిబంధనలకు లోబడి ఉండాలి:',
                isDark,
              ),
              _buildParagraph('• కంటెంట్ ఖచ్చితమైనది మరియు వాస్తవికమైనదిగా ఉండాలి.', isDark),
              _buildParagraph('• విద్వేషపూరిత, వేధింపులు లేదా రెచ్చగొట్టే భాషను ఉపయోగించకూడదు.', isDark),
              _buildParagraph('• అన్ని ఫోటోలు, వీడియోలు అసలైనవి లేదా తగిన లైసెన్స్ కలిగి ఉండాలి.', isDark),
              _buildParagraph('ఈ విధానాలను ఉల్లంఘిస్తే కథనం తిరస్కరించబడుతుంది మరియు రిపోర్టర్ ఖాతా తాత్కాలికంగా రద్దు చేయబడవచ్చు.', isDark),
              const SizedBox(height: 32),
            ],
          const SizedBox(height: 32),
          _buildSectionHeader('తరచుగా అడిగే ప్రశ్నలు (FAQ)', isDark),
          const SizedBox(height: 16),
          _buildFaqItem(
            context,
            'నేను రిపోర్టర్‌గా ఎలా మారాలి?',
            'ఎవరైనా చేరవచ్చు! మీ ప్రొఫైల్‌కు వెళ్లి, రిపోర్టర్ కార్డుపై "చేరండి" నొక్కి, మీ ఫోన్ నంబర్‌ను OTP ద్వారా ధృవీకరించి స్థానిక వార్తలను పోస్ట్ చేయడం ప్రారంభించండి.',
            isDark,
          ),
          _buildFaqItem(
            context,
            'నేను టోకెన్లు ఎలా సంపాదించాలి?',
            'మీరు రిపోర్టర్ అయిన తర్వాత వార్తలను సమర్పించండి. మా అడ్మిన్ డెస్క్ ఆమోదించి ప్రచురించిన ప్రతి కథనానికి 1 టోకెన్ (₹5) లభిస్తుంది.',
            isDark,
          ),
          _buildFaqItem(
            context,
            'నేను నా ఆదాయాన్ని ఎప్పుడు విత్‌డ్రా చేసుకోవచ్చు?',
            'మీరు 100 టోకెన్లు (₹500) సంపాదించిన తర్వాత మీ UPI ID కి విత్‌డ్రా అభ్యర్థనను పంపవచ్చు.',
            isDark,
          ),
          _buildFaqItem(
            context,
            'నా కథనం ఎందుకు తిరస్కరించబడింది?',
            'కంటెంట్ విధానాలను ఉల్లంఘించినా, సరైన వివరాలు లేకపోయినా లేదా మీడియా నాణ్యత తక్కువగా ఉన్నా కథనాలు తిరస్కరించబడతాయి.',
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
