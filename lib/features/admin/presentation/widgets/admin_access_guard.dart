import 'package:flutter/material.dart';
import '../../../../state/app_state.dart';
import '../theme/admin_colors.dart';
import 'admin_status_state.dart';

/// Whether the signed-in account may use the moderation console.
///
/// Deliberately mirrors the gate on the profile entry card
/// (profile_tab.dart) so the two cannot drift: contributors moderate
/// alongside full admins.
bool get hasAdminConsoleAccess =>
    AppState.instance.isAdmin || AppState.instance.isContributor;

/// Refuses to build an admin screen for non-admins.
///
/// The profile entry card is already gated, but that only covers one way in.
/// Deep links, a restored route or a stray `Navigator.push` would otherwise
/// render the full moderation UI and let every call fail with a 403 — a wall
/// of errors that also leaks what the console can do. Guarding the screen
/// itself closes that off at the destination.
class AdminAccessGuard extends StatelessWidget {
  final Widget child;

  const AdminAccessGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (hasAdminConsoleAccess) return child;
    return const AdminAccessDenied();
  }
}

/// The refusal screen on its own, for admin screens that prefer to
/// early-return it from `build` rather than wrap their whole tree.
class AdminAccessDenied extends StatelessWidget {
  const AdminAccessDenied({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: AdminColors.scaffold(isDark),
      appBar: AppBar(
        backgroundColor: AdminColors.scaffold(isDark),
        foregroundColor: AdminColors.textPrimary(isDark),
        elevation: 0,
        title: const Text('పర్యవేక్షణ', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ),
      body: const AdminStatusState(
        icon: Icons.admin_panel_settings_outlined,
        title: 'అడ్మిన్‌లకు మాత్రమే',
        message: 'ఈ పర్యవేక్షణ కన్సోల్ అడ్మిన్‌గా గుర్తించిన ఖాతాలకు మాత్రమే అందుబాటులో ఉంటుంది.',
      ),
    );
  }
}
