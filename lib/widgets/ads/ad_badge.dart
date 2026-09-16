import 'package:flutter/material.dart';

/// The `Ad` chip that sits on every image-based ad creative.
///
/// Top-right per the design reference, and one widget rather than a copy per
/// ad type — three of them (three_d, poster, video) had no disclosure at all,
/// which is the kind of gap that only appears once they are side by side.
///
/// Opaque backing on purpose: a disclosure has to stay legible on any
/// artwork, including a white one.
class AdBadge extends StatelessWidget {
  const AdBadge({super.key, this.label = 'Ad'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  /// Positioned top-right inside a Stack, as the reference shows.
  static Widget positioned({String label = 'Ad'}) => Positioned(
        top: 8,
        right: 8,
        child: IgnorePointer(child: AdBadge(label: label)),
      );
}
