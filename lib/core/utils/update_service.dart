import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

/// Checks Google Play for a newer version and, if one exists, downloads
/// it quietly in the background (flexible update) — never blocks or
/// interrupts the current session. Once downloaded, prompts the user to
/// restart and apply it. Silently does nothing on builds not installed
/// via Google Play (sideloaded APKs, iOS) — this is Play-Store-specific.
///
/// This is deliberately fire-and-forget: call it from main() without
/// awaiting, so it never delays the first frame. A forced/immediate
/// update path (for breaking changes, e.g. once the league backend
/// ships) is a separate, later addition — this is just the routine
/// "nudge users onto the latest version" piece.
class UpdateService {
  Future<void> checkForFlexibleUpdate() async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) return;
      if (!info.flexibleUpdateAllowed) return;

      await InAppUpdate.startFlexibleUpdate();
      // Download happens in the background from here. Once it completes,
      // Play Store's own UI shows a "Restart to update" snackbar-style
      // prompt automatically — nothing further needed on our side for
      // the basic flow.
    } catch (e) {
      // Never let an update-check failure affect the app itself — this
      // is a nice-to-have nudge, not a critical path.
      debugPrint('UpdateService: check failed (non-fatal): $e');
    }
  }
}

final updateService = UpdateService();
