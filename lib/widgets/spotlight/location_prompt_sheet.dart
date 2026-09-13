import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';
import '../../screens/location_selection_screen.dart';

class LocationPromptSheet extends StatefulWidget {
  const LocationPromptSheet({super.key});

  @override
  State<LocationPromptSheet> createState() => _LocationPromptSheetState();
}

class _LocationPromptSheetState extends State<LocationPromptSheet>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _rippleController;

  @override
  void initState() {
    super.initState();
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _rippleController.dispose();
    super.dispose();
  }

  Future<void> _detectLocation() async {
    setState(() => _isLoading = true);
    _rippleController.duration = const Duration(milliseconds: 800);
    _rippleController.repeat();

    try {
      final deviceLocation = await LocationService.detectLocation();
      final match =
          await ApiService.instance.resolveCanonicalLocation(deviceLocation);
      if (!mounted) return;
      final confirmed = await LocationService.showCanonicalConfirmation(
        context,
        match,
      );
      if (!mounted) return;
      if (!confirmed) {
        setState(() => _isLoading = false);
        final changed = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => const LocationSelectionScreen(),
          ),
        );
        if (changed == true && mounted) Navigator.pop(context, true);
        return;
      }
      await ApiService.instance.applyCanonicalLocation(match);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } on LocationException catch (exception) {
      _showError(exception.message);
    } catch (e) {
      _showError('Failed to get location: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _rippleController.duration = const Duration(milliseconds: 1500);
      _rippleController.repeat();
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    // We do NOT pop here. Let them try again or manually decline.
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Grabber
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Animated Radar Icon
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _rippleController,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: _RadarRipplePainter(
                          progress: _rippleController.value,
                          color: AppColors.primary,
                          isActive: _isLoading,
                        ),
                        size: const Size(120, 120),
                      );
                    },
                  ),
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.location_on_rounded,
                        color: Colors.white, size: 32),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Text(
              'మీ ప్రాంత వార్తలు కావాలా?',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                  letterSpacing: -0.5),
            ),
            const SizedBox(height: 8),
            const Text(
              'మీ గ్రామం, మండలం మరియు జిల్లా తాజా వార్తలను ఎప్పటికప్పుడు పొందడానికి లొకేషన్ అనుమతిని ఇవ్వండి.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textMuted, fontSize: 14.5, height: 1.4),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: _isLoading ? null : _detectLocation,
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text('అనుమతించండి (Allow)',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed:
                  _isLoading ? null : () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              ),
              child: const Text('ప్రస్తుతానికి వద్దు (Maybe Later)',
                  style: TextStyle(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                      fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadarRipplePainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool isActive;

  _RadarRipplePainter({
    required this.progress,
    required this.color,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (int i = 0; i < 2; i++) {
      final waveProgress = (progress + (i * 0.5)) % 1.0;
      final radius = maxRadius * waveProgress;
      // Faster, bolder ripples when active loading
      final maxOpacity = isActive ? 0.5 : 0.2;
      final opacity = (1.0 - waveProgress).clamp(0.0, 1.0) * maxOpacity;

      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isActive ? 3.0 : 1.5;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarRipplePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isActive != isActive;
  }
}
