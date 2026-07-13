import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// A mock anchored banner ad slot (~320x50 style), meant to sit above the
/// bottom nav bar. Swap the child content for a real ad SDK banner
/// (e.g. google_mobile_ads' AdWidget) when wiring up real monetization.
class BannerAdSlot extends StatelessWidget {
  const BannerAdSlot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      width: double.infinity,
      color: const Color(0xFFEDEDEF),
      alignment: Alignment.center,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.ads_click, size: 14, color: AppColors.textMuted),
          SizedBox(width: 6),
          Text(
            'Advertisement · 320x50 banner slot',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
