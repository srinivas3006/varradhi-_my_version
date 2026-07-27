import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../models/ad_banner.dart';
import '../../services/api_service.dart';

class AdBannerWidget extends StatefulWidget {
  final AdBanner ad;
  
  const AdBannerWidget({super.key, required this.ad});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  bool _impressionTracked = false;

  void _onVisibilityChanged(VisibilityInfo info) {
    if (!_impressionTracked && info.visibleFraction > 0.5) {
      _impressionTracked = true;
      ApiService.instance.trackAdEvent(widget.ad.id, 'impression');
    }
  }

  Future<void> _handleTap() async {
    ApiService.instance.trackAdEvent(widget.ad.id, 'click');
    if (widget.ad.destinationUrl.isNotEmpty) {
      final uri = Uri.tryParse(widget.ad.destinationUrl);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('ad_${widget.ad.id}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: GestureDetector(
        onTap: _handleTap,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 8),
          color: Colors.black, // Background while loading
          child: CachedNetworkImage(
            imageUrl: widget.ad.imageUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) => const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ),
            ),
            errorWidget: (context, url, error) => const Icon(Icons.error),
          ),
        ),
      ),
    );
  }
}
