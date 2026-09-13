import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/ads/banner_ad_slot.dart';

class MagazineItem {
  final String id;
  final String title;
  final String coverUrl;
  final String pdfUrl;
  final String issueDate;

  MagazineItem({
    required this.id,
    required this.title,
    required this.coverUrl,
    required this.pdfUrl,
    required this.issueDate,
  });
}

class MagazinesScreen extends StatefulWidget {
  const MagazinesScreen({super.key});

  @override
  State<MagazinesScreen> createState() => _MagazinesScreenState();
}

class _MagazinesScreenState extends State<MagazinesScreen> {
  final List<MagazineItem> _magazines = [];
  final bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('డిజిటల్ మ్యాగజైన్‌లు (Magazines)')),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _magazines.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.menu_book_rounded, size: 48, color: AppColors.textMuted),
                              SizedBox(height: 12),
                              Text(
                                'ప్రస్తుతానికి మ్యాగజైన్‌లు అందుబాటులో లేవు',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'కొత్త సంచికలు మరియు ఈ-పేపర్లు ప్రచురించబడినప్పుడు ఇక్కడ కనిపిస్తాయి.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _magazines.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 0.68,
                        ),
                        itemBuilder: (context, index) {
                          final magazine = _magazines[index];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.network(
                                    magazine.coverUrl,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    errorBuilder: (_, __, ___) => Container(color: AppColors.chipBg),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                magazine.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                              ),
                              Text(
                                magazine.issueDate,
                                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                              ),
                            ],
                          );
                        },
                      ),
          ),
          const BannerAdSlot(),
        ],
      ),
    );
  }
}
