import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// A per-(device, app signing key) identifier that survives a reinstall —
/// on Android, `Settings.Secure.ANDROID_ID` (exposed as
/// [AndroidDeviceInfo.id] by device_info_plus). It only changes on a
/// factory reset or if the app switches signing keys, which is exactly
/// what makes it useful for spotting "this is the same phone that already
/// has an account" reinstall churn — see ensurePlayerDocument's use of it.
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
      final info = await DeviceInfoPlugin().androidInfo;
      final id = info.id;
      if (id.isEmpty) return null;
      _cached = id;
      return id;
    } catch (e, st) {
      debugPrint('DeviceIdService failed to read Android ID (non-fatal): $e\n$st');
      return null;
    }
  }
}

final deviceIdService = DeviceIdService();
