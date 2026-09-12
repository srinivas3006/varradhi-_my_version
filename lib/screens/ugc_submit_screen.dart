import 'package:flutter/material.dart';
import 'create_post_screen.dart';

/// Screen 15: UGCSubmitScreen (Alias for CreatePostScreen)
/// - APIs: ugc/send-otp, ugc/verify-otp, ugc/submit, ugc/upload-media
/// - Destination: UGCReporterDashboard
class UGCSubmitScreen extends StatelessWidget {
  const UGCSubmitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CreatePostScreen();
  }
}
