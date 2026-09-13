import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/ad_banner.dart';
import '../../services/ad_manager.dart';
import '../../theme/app_theme.dart';
import 'ad_viewability_detector.dart';

/// Premium interactive 3D promotional ad card (Aspect ratio: 4:3, height ~260-320dp)
/// Features an interactive 3D perspective tilt & specular reflection on touch gesture.
class ThreeDAdWidget extends StatefulWidget {
  final AdBanner ad;
  final String placementZone;
  final String? exposureKey;

  const ThreeDAdWidget({
    super.key,
    required this.ad,
    this.placementZone = 'feed',
    this.exposureKey,
  });

  @override
  State<ThreeDAdWidget> createState() => _ThreeDAdWidgetState();
}

class _ThreeDAdWidgetState extends State<ThreeDAdWidget>
    with SingleTickerProviderStateMixin {
  bool _hasError = false;
  double _tiltX = 0.0;
  double _tiltY = 0.0;
  late AnimationController _reboundController;
  late Animation<double> _reboundX;
  late Animation<double> _reboundY;

  @override
  void initState() {
    super.initState();
    _reboundController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..addListener(() {
        setState(() {
          _tiltX = _reboundX.value;
          _tiltY = _reboundY.value;
        });
      });
  }

  @override
  void dispose() {
    _reboundController.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details, Size size) {
    if (size.width == 0 || size.height == 0) return;
    _reboundController.stop();

    // Map gesture delta to subtle tilt angles (max ~0.15 radians)
    final dx = (details.localPosition.dx - size.width / 2) / (size.width / 2);
    final dy = (details.localPosition.dy - size.height / 2) / (size.height / 2);

    setState(() {
      _tiltY = dx.clamp(-1.0, 1.0) * 0.12;
      _tiltX = -dy.clamp(-1.0, 1.0) * 0.12;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    _reboundX = Tween<double>(begin: _tiltX, end: 0.0).animate(
      CurvedAnimation(parent: _reboundController, curve: Curves.easeOutBack),
    );
    _reboundY = Tween<double>(begin: _tiltY, end: 0.0).animate(
      CurvedAnimation(parent: _reboundController, curve: Curves.easeOutBack),
    );
    _reboundController.forward(from: 0.0);
  }

  Future<void> _handleTap() async {
    HapticFeedback.selectionClick();
    AdManager.instance.recordClick(widget.ad, placementZone: widget.placementZone);
    if (widget.ad.destinationUrl.isNotEmpty) {
      final uri = Uri.tryParse(widget.ad.destinationUrl);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AdViewabilityDetector(
      ad: widget.ad,
      placementZone: widget.placementZone,
      exposureKey: widget.exposureKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxWidth * (3 / 4));

          // 3D perspective transformation matrix
          final transform = Matrix4.identity()
            ..setEntry(3, 2, 0.001) // perspective
            ..rotateX(_tiltX)
            ..rotateY(_tiltY);

          return GestureDetector(
            onPanUpdate: (d) => _onPanUpdate(d, size),
            onPanEnd: _onPanEnd,
            onPanCancel: () => _onPanEnd(DragEndDetails()),
            onTap: _handleTap,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Transform(
                transform: transform,
                alignment: FractionalOffset.center,
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1B1B1F) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF6366F1).withValues(alpha: 0.35)
                          : const Color(0xFF6366F1).withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.25 : 0.12),
                        blurRadius: 20,
                        offset: Offset(_tiltY * 30, 8 - _tiltX * 30),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: AspectRatio(
                    aspectRatio: 4 / 3, // Fixed 4:3 aspect ratio per spec
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: widget.ad.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: isDark ? Colors.white10 : AppColors.chipBg,
                            child: const Center(
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) setState(() => _hasError = true);
                            });
                            return const SizedBox.shrink();
                          },
                        ),

                        // Specular lighting sheen layer shifting with tilt
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment(-1.0 + _tiltY * 3, -1.0 - _tiltX * 3),
                                  end: Alignment(1.0 + _tiltY * 3, 1.0 - _tiltX * 3),
                                  colors: [
                                    Colors.white.withValues(alpha: 0.22),
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.2),
                                  ],
                                  stops: const [0.0, 0.5, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Premium 3D Sponsored Badge
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_awesome, size: 12, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  '3D Sponsored',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Interactive Hint
                        Positioned(
                          bottom: 10,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.touch_app_rounded, size: 12, color: Colors.white70),
                                SizedBox(width: 4),
                                Text(
                                  'Tilt to interact',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
