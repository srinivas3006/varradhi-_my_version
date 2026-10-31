import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// Asks the reader to update when a newer version is live on Google Play.
///
/// Play itself is asked (In-App Updates API), so publishing a release is
/// all it takes — no backend version field to keep in sync. Only works for
/// installs from Play; a sideloaded or debug build gets an error from Play,
/// which is ignored. The prompt shows once per app launch, and "Later"
/// lets the reader carry on.
class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  /// Play Store id (`applicationId` in android/app/build.gradle.kts).
  static const String packageName = 'com.varadhi';

  bool _checkedThisLaunch = false;

  @visibleForTesting
  void resetForTest() => _checkedThisLaunch = false;

  Future<void> checkAndPrompt(BuildContext context) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (_checkedThisLaunch) return;
    _checkedThisLaunch = true;

    try {
      // No timeout: Play always answers (an update result or an error), and
      // nothing waits on this — the prompt simply never shows if it doesn't.
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return;
      }
      if (!context.mounted) return;
      await _showPrompt(context);
    } catch (e) {
      // Not installed from Play, no Play services, or offline.
      debugPrint('[AppUpdate] update check skipped: $e');
    }
  }

  Future<void> _showPrompt(BuildContext context) {
    final telugu = AppState.instance.language == 'Telugu';
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.system_update_rounded,
            size: 40, color: AppColors.primary),
        title: Text(
          telugu ? 'కొత్త వెర్షన్ అందుబాటులో ఉంది' : 'Update available',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          telugu
              ? 'వారధి న్యూస్ కొత్త వెర్షన్ విడుదలైంది. తాజా ఫీచర్లు మరియు మెరుగుదలల కోసం ఇప్పుడే అప్‌డేట్ చేయండి.'
              : 'A new version of Vaaradhi News is out. Update now for the latest features and fixes.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(telugu ? 'తర్వాత' : 'Later'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              unawaited(openPlayStore());
            },
            child: Text(telugu ? 'అప్‌డేట్ చేయండి' : 'Update'),
          ),
        ],
      ),
    );
  }

  /// The app's Play Store page: the Play app when present, else the web.
  Future<void> openPlayStore() async {
    final market = Uri.parse('market://details?id=$packageName');
    final web = Uri.parse(
        'https://play.google.com/store/apps/details?id=$packageName');
    try {
      if (await launchUrl(market, mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {}
    try {
      await launchUrl(web, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[AppUpdate] could not open Play Store: $e');
    }
  }
}
