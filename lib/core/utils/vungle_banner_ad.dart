import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum VungleBannerSize { banner, mrec }

extension on VungleBannerSize {
  String get wireName => switch (this) {
        VungleBannerSize.banner => 'banner',
        VungleBannerSize.mrec => 'mrec',
      };

  Size get logicalSize => switch (this) {
        VungleBannerSize.banner => const Size(320, 50),
        VungleBannerSize.mrec => const Size(300, 250),
      };
}

/// Embeds a Vungle (Liftoff Monetize) banner or MREC via a native
/// PlatformView — see android/app/.../vungle_ads/ for the Kotlin side.
/// Same rationale as MetaBannerAd: no actively-maintained standalone
/// Flutter plugin exists for direct (non-AdMob-mediated) Vungle
/// integration, so this talks to the native SDK directly instead.
///
/// Android only for now — see VungleBannerAdFactory (native side) has
/// no iOS counterpart yet.
class VungleBannerAd extends StatefulWidget {
  final String placementId;
  final VungleBannerSize size;
  final VoidCallback? onLoad;
  final void Function(int errorCode, String errorMessage)? onFailed;

  const VungleBannerAd({
    super.key,
    required this.placementId,
    this.size = VungleBannerSize.banner,
    this.onLoad,
    this.onFailed,
  });

  @override
  State<VungleBannerAd> createState() => _VungleBannerAdState();
}

class _VungleBannerAdState extends State<VungleBannerAd> {
  @override
  Widget build(BuildContext context) {
    final logicalSize = widget.size.logicalSize;
    if (defaultTargetPlatform != TargetPlatform.android) {
      return SizedBox.fromSize(size: logicalSize);
    }
    return SizedBox.fromSize(
      size: logicalSize,
      child: AndroidView(
        viewType: 'vungle_banner_ad',
        creationParams: {
          'placementId': widget.placementId,
          'size': widget.size.wireName,
        },
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
      ),
    );
  }

  void _onPlatformViewCreated(int id) {
    final channel = MethodChannel('vungle_banner_ad_$id');
    channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onAdLoaded':
          widget.onLoad?.call();
        case 'onAdFailed':
          final args = Map<String, dynamic>.from(call.arguments as Map);
          widget.onFailed?.call(
            args['errorCode'] as int? ?? -1,
            args['errorMessage'] as String? ?? 'unknown error',
          );
      }
    });
  }
}
