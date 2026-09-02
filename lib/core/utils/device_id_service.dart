import 'package:android_id/android_id.dart';
import 'package:flutter/foundation.dart';

/// A per-(device, app signing key) identifier that survives a reinstall —
/// on Android, `Settings.Secure.ANDROID_ID`, read via the dedicated
/// android_id plugin. It only changes on a factory reset or if the app
/// switches signing keys, which is exactly what makes it useful for
/// spotting "this is the same phone that already has an account" reinstall
/// churn — see ensurePlayerDocument's use of it.
///
/// NOTE: this used to read [AndroidDeviceInfo.id] from device_info_plus,
/// which despite its name is `Build.ID` (the OS build fingerprint, e.g.
/// "CP2A.260805.005") — identical across every device on the same
/// firmware, not remotely per-device. That bug shipped and had the
/// server-side duplicate-account pruning treating unrelated real players
/// as reinstall duplicates. Don't revert to device_info_plus for this.
///
/// Cached after the first successful read since it never changes for the
/// lifetime of an install. Returns null on non-Android platforms or if
/// the platform channel call fails — callers treat that as "can't tell,"
/// never as a hard error.
class DeviceIdService {
  String? _cached;

  Future<String?> getDeviceId() async {
    if (_cached != null) return _cached;
    if (defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final id = await const AndroidId().getId();
      if (id == null || id.isEmpty) return null;
      _cached = id;
      return id;
    } catch (e, st) {
      debugPrint('DeviceIdService failed to read Android ID (non-fatal): $e\n$st');
      return null;
    }
  }
}

final deviceIdService = DeviceIdService();
