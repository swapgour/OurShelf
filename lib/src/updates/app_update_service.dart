import 'dart:io';

import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

import '../app.dart' show scaffoldMessengerKey;

/// Checks the Play Store for a newer version and, if one's available,
/// downloads it in the background (a "flexible" update) and prompts to
/// restart once it's ready. Play Store already auto-updates most installs
/// silently on its own schedule — this just nudges anyone who has that
/// disabled, or who opens the app before Play Store gets to it, so a new
/// release reaches people sooner.
///
/// Android only, and only works for a build actually installed through
/// Play (the plugin throws otherwise — e.g. a sideloaded APK, or no Play
/// Store on the device). Both cases are swallowed silently: this is a
/// nice-to-have that must never block or disrupt app startup.
class AppUpdateService {
  const AppUpdateService();

  Future<void> checkForUpdate() async {
    if (!Platform.isAndroid) return;
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return;
      }
      if (info.flexibleUpdateAllowed) {
        await InAppUpdate.startFlexibleUpdate();
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            duration: const Duration(days: 1),
            content: const Text('An update has downloaded.'),
            action: SnackBarAction(
              label: 'Restart',
              onPressed: () {
                InAppUpdate.completeFlexibleUpdate();
              },
            ),
          ),
        );
      } else if (info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
      }
    } catch (_) {
      // Not a Play-installed build, no Play Store on the device, or a
      // transient network error — never block startup over this.
    }
  }
}
