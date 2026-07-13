import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_theme.dart';

class SpotlightPromoCard extends StatelessWidget {
  final String imageUrl;

  const SpotlightPromoCard({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(color: AppColors.chipBg),
            errorWidget: (context, url, error) => Container(
              color: AppColors.chipBg,
              child: const Center(
                child: Icon(Icons.image_not_supported_outlined, color: AppColors.textMuted, size: 40),
              ),
            ),
          ),
          // Gradient at top for close button visibility
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 120,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
