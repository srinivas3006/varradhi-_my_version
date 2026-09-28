import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../screens/location_selection_screen.dart';
import '../state/app_state.dart';
import 'api_service.dart';
import 'location_service.dart';

enum LocationPromptReason {
  spotlight,
  localNews,
  post,
  manual,
}

class LocationPermissionCoordinator {
  const LocationPermissionCoordinator._();

  static Future<bool> shouldShowAutomaticPrompt() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      return false;
    }
    if (permission == LocationPermission.deniedForever) {
      AppState.instance.markLocationPermissionDenied(forever: true);
      return false;
    }
    return AppState.instance.shouldAutoPromptLocation();
  }

  static Future<bool> requestCurrentLocation(
    BuildContext context, {
    LocationPromptReason reason = LocationPromptReason.manual,
    bool respectCooldown = false,
  }) async {
    if (!context.mounted) return false;
    if (respectCooldown && !await shouldShowAutomaticPrompt()) return false;
    if (!context.mounted) return false;

    AppState.instance.markLocationPrompted();
    final accepted = await _showSoftPrompt(context, reason: reason);
    if (!context.mounted) return false;
    if (accepted == _LocationPromptChoice.later) {
      AppState.instance.markLocationPromptDismissed();
      return false;
    }
    if (accepted == _LocationPromptChoice.manual) {
      return chooseLocationManually(context);
    }

    return detectAndApply(context, recordPrompt: false);
  }

  /// Requests native permission (if not already resolved) and, once granted,
  /// detects, confirms and applies the device's current location.
  ///
  /// Call this directly — skipping the soft sheet — from a control whose tap
  /// already *is* the "use current location" intent, such as a GPS icon on
  /// the Local tab or a button inside a screen's own explanatory sheet. The
  /// soft sheet in [requestCurrentLocation] exists to manufacture that
  /// intent for prompts we show proactively; a place that already has it
  /// should not show a second sheet asking for it again.
  static Future<bool> detectAndApply(
    BuildContext context, {
    bool recordPrompt = true,
  }) async {
    if (!context.mounted) return false;
    if (recordPrompt) AppState.instance.markLocationPrompted();
    final permission = await _requestNativePermission();
    if (!context.mounted) return false;
    if (permission == LocationPermission.deniedForever) {
      AppState.instance.markLocationPermissionDenied(forever: true);
      _showSettingsSnackBar(context);
      return false;
    }
    if (permission == LocationPermission.denied) {
      AppState.instance.markLocationPermissionDenied();
      return chooseLocationManually(context);
    }

    try {
      final deviceLocation = await LocationService.detectLocation(
        requestPermission: false,
      );
      final match =
          await ApiService.instance.resolveCanonicalLocation(deviceLocation);
      if (!context.mounted) return false;
      final confirmed =
          await LocationService.showCanonicalConfirmation(context, match);
      if (!context.mounted) return false;
      if (!confirmed) return chooseLocationManually(context);

      await ApiService.instance.applyCanonicalLocation(match);
      return true;
    } on LocationException catch (exception) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(exception.message)));
      }
      return false;
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location failed: $error')),
        );
      }
      return false;
    }
  }

  static Future<bool> chooseLocationManually(BuildContext context) async {
    if (!context.mounted) return false;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LocationSelectionScreen()),
    );
    return changed == true;
  }

  static Future<LocationPermission> _requestNativePermission() async {
    final current = await Geolocator.checkPermission();
    if (current == LocationPermission.always ||
        current == LocationPermission.whileInUse ||
        current == LocationPermission.deniedForever) {
      return current;
    }
    return Geolocator.requestPermission();
  }

  static void _showSettingsSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Location permission is blocked in settings.'),
        action: SnackBarAction(
          label: 'Settings',
          onPressed: Geolocator.openAppSettings,
        ),
      ),
    );
  }

  static Future<_LocationPromptChoice> _showSoftPrompt(
    BuildContext context, {
    required LocationPromptReason reason,
  }) async {
    final copy = _copyFor(reason);
    return await showModalBottomSheet<_LocationPromptChoice>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          useSafeArea: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (sheetContext) => SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                4,
                20,
                MediaQuery.paddingOf(sheetContext).bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Theme.of(sheetContext)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.my_location_rounded,
                          color: Theme.of(sheetContext).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          copy.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    copy.body,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color:
                          Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(
                        sheetContext,
                        _LocationPromptChoice.current,
                      ),
                      icon: const Icon(Icons.my_location_rounded),
                      label: Text(copy.primary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(
                        sheetContext,
                        _LocationPromptChoice.manual,
                      ),
                      icon: const Icon(Icons.edit_location_alt_rounded),
                      label: const Text('Choose manually'),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(
                      sheetContext,
                      _LocationPromptChoice.later,
                    ),
                    child: const Text('Maybe later'),
                  ),
                ],
              ),
            ),
          ),
        ) ??
        _LocationPromptChoice.later;
  }

  static _LocationPromptCopy _copyFor(LocationPromptReason reason) {
    switch (reason) {
      case LocationPromptReason.post:
        return const _LocationPromptCopy(
          title: 'Add location to your report',
          body:
              'Citizen reports need a trusted area so editors and readers know where the news happened.',
          primary: 'Use current location',
        );
      case LocationPromptReason.localNews:
        return const _LocationPromptCopy(
          title: 'Get news from your area',
          body:
              'Use your current location once to show village, mandal, and district news. You can also choose manually.',
          primary: 'Use current location',
        );
      case LocationPromptReason.spotlight:
        return const _LocationPromptCopy(
          title: 'Make Spotlight local',
          body:
              'Set your area to mix nearby stories into Spotlight without interrupting your reading again and again.',
          primary: 'Use current location',
        );
      case LocationPromptReason.manual:
        return const _LocationPromptCopy(
          title: 'Set your news location',
          body:
              'Choose GPS or manual selection to personalize local news for your area.',
          primary: 'Use current location',
        );
    }
  }
}

enum _LocationPromptChoice { current, manual, later }

class _LocationPromptCopy {
  const _LocationPromptCopy({
    required this.title,
    required this.body,
    required this.primary,
  });

  final String title;
  final String body;
  final String primary;
}
