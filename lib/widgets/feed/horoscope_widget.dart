// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../theme/app_theme.dart';
import '../../localization/app_translations.dart';

class HoroscopeWidget extends StatefulWidget {
  const HoroscopeWidget({super.key});

  @override
  State<HoroscopeWidget> createState() => _HoroscopeWidgetState();
}

class _HoroscopeWidgetState extends State<HoroscopeWidget> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isGeneratingPdf = false;

  final List<Map<String, String>> _signs = [
    {'sign': 'Aries (Mesha)', 'prediction': 'Good day for financial investments. Avoid arguments.'},
    {'sign': 'Taurus (Vrishabha)', 'prediction': 'Unexpected gains. Take care of your health.'},
    {'sign': 'Gemini (Mithuna)', 'prediction': 'Focus on career today. Travel is favorable.'},
    {'sign': 'Cancer (Karka)', 'prediction': 'Family time is highlighted. Positive news awaits.'},
    {'sign': 'Leo (Simha)', 'prediction': 'Take bold decisions. A great day for networking.'},
    {'sign': 'Virgo (Kanya)', 'prediction': 'Be cautious with expenses. Meditation will help.'},
    {'sign': 'Libra (Tula)', 'prediction': 'New relationships may form. Creative energy is high.'},
    {'sign': 'Scorpio (Vrishchika)', 'prediction': 'Challenges at work, but you will overcome them.'},
    {'sign': 'Sagittarius (Dhanu)', 'prediction': 'Spiritual growth and learning are in focus.'},
    {'sign': 'Capricorn (Makara)', 'prediction': 'Hard work pays off. Good news from a distance.'},
    {'sign': 'Aquarius (Kumbha)', 'prediction': 'Focus on your goals. Support from friends.'},
    {'sign': 'Pisces (Meena)', 'prediction': 'Trust your intuition. A peaceful day ahead.'},
  ];

  Future<void> _shareAsPdf() async {
    if (_isGeneratingPdf) return;
    setState(() => _isGeneratingPdf = true);

    try {
      // Capture a hidden widget that contains all signs in a grid
      final Uint8List imageBytes = await _screenshotController.captureFromWidget(
        Material(
          color: Colors.white,
          child: Container(
            padding: const EdgeInsets.all(24),
            width: 800, // Fixed width for high-quality capture
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.orange, size: 32),
                    SizedBox(width: 12),
                    Text(
                      'Daily Horoscope (Jyothishyam)',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: _signs.map((signData) {
                    return Container(
                      width: 350,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            signData['sign']!,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            signData['prediction']!,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Brought to you by Vaaradhi',
                  style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold),
                )
              ],
            ),
          ),
        ),
        delay: const Duration(milliseconds: 200),
      );

      final pdf = pw.Document();
      final image = pw.MemoryImage(imageBytes);

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Center(child: pw.Image(image));
        },
      ));

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/jyothishyam_today.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([XFile(file.path)], text: 'Today\'s Horoscope');
    } catch (e) {
      debugPrint("Error generating PDF: $e");
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.orange, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      tr('horoscope'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: _isGeneratingPdf ? null : _shareAsPdf,
                  child: Row(
                    children: [
                      if (_isGeneratingPdf)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        )
                      else
                        const Icon(Icons.picture_as_pdf, size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      const Text(
                        'Share PDF',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _signs.length,
              itemBuilder: (context, index) {
                final sign = _signs[index];
                return Container(
                  width: 240,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                    color: isDark ? Colors.orange.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? Colors.orange.withValues(alpha: 0.3) : Colors.orange.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sign['sign']!,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.orangeAccent : Colors.deepOrange,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Text(
                          sign['prediction']!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : Colors.black87,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
