import 'package:flutter/material.dart';
import '../data/mock_magazines.dart';
import '../theme/app_theme.dart';
import '../widgets/ads/banner_ad_slot.dart';

class MagazinesScreen extends StatelessWidget {
  const MagazinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Digital Magazines')),
      body: Column(
        children: [
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: mockMagazines.length + 1, // +1 native ad tile
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.68,
              ),
              itemBuilder: (context, index) {
                // Insert one native ad tile after the 3rd magazine.
                if (index == 3) return const _MagazineAdTile();
                final magazineIndex = index > 3 ? index - 1 : index;
                if (magazineIndex >= mockMagazines.length) {
                  return const SizedBox.shrink();
                }
                final magazine = mockMagazines[magazineIndex];
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
                          errorBuilder: (_, __, ___) =>
                              Container(color: AppColors.chipBg),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(magazine.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13.5)),
                    Text(magazine.issueDate,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted)),
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

class _MagazineAdTile extends StatelessWidget {
  const _MagazineAdTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F1FF),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.storefront_rounded, size: 32, color: Color(0xFFB9AEF5)),
          SizedBox(height: 6),
          Text('Ad', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
