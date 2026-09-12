import 'package:flutter/material.dart';
import 'my_posts_screen.dart';

/// Screen 16: UGCReporterDashboard (Alias for MyPostsScreen)
/// - APIs: ugc/reporter/dashboard, ugc/reporter/submissions
/// - Destination: submission status list
class UGCReporterDashboard extends StatelessWidget {
  const UGCReporterDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const MyPostsScreen();
  }
}
