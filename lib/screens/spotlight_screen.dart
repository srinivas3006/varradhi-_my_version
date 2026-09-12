import 'package:flutter/material.dart';
import '../spotlight/spotlight_screen.dart';

class SpotlightScreen extends StatelessWidget {
  final String? initialStoryId;
  final int? initialStoryIndex;
  final String? initialCategory;
  final bool isLocal;

  const SpotlightScreen({
    super.key,
    this.initialStoryId,
    this.initialStoryIndex,
    this.initialCategory,
    this.isLocal = false,
  });

  @override
  Widget build(BuildContext context) {
    return SpotlightScreenView(
      initialStoryId: initialStoryId,
      initialStoryIndex: initialStoryIndex,
      initialCategory: initialCategory,
      isLocal: isLocal,
    );
  }
}
