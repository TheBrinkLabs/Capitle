import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Reads the app's version + build number directly from pubspec.yaml at
/// runtime (via the platform's package manifest), so the version shown in
/// Settings always matches what's actually installed — no manual updates
/// needed on every release.
final packageInfoProvider = FutureProvider<PackageInfo>((ref) {
  return PackageInfo.fromPlatform();
});
