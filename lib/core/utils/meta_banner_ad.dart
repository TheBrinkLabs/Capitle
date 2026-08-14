import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum MetaBannerSize { banner, mrec }

extension on MetaBannerSize {
  String get wireName => switch (this) {
        MetaBannerSize.banner => 'banner',
        MetaBannerSize.mrec => 'mrec',
      };

  Size get logicalSize => switch (this) {
        MetaBannerSize.banner => const Size(320, 50),
        MetaBannerSize.mrec => const Size(300, 250),
      };
}

/// Embeds a Meta Audience Network AdView (banner or MREC) via a native
/// PlatformView — see android/app/.../meta_ads/ for the Kotlin side.
/// Meta has no actively-maintained direct Flutter plugin: the only one
/// still updated requires an AdMob account underneath (routes through
/// Google Mobile Ads mediation), and the standalone ones have been
/// abandoned for years. This talks to Meta's native SDK directly
/// instead of depending on either.
///
/// Android only for now — see MetaBannerAdFactory (native side) has no
/// iOS counterpart yet.
class MetaBannerAd extends StatefulWidget {
  final String placementId;
  final MetaBannerSize size;
  final VoidCallback? onLoad;
  final void Function(int errorCode, String errorMessage)? onFailed;

  const MetaBannerAd({
    super.key,
    required this.placementId,
    this.size = MetaBannerSize.banner,
    this.onLoad,
    this.onFailed,
  });

  @override
  State<MetaBannerAd> createState() => _MetaBannerAdState();
}

class _MetaBannerAdState extends State<MetaBannerAd> {
  @override
  Widget build(BuildContext context) {
    final logicalSize = widget.size.logicalSize;
    if (defaultTargetPlatform != TargetPlatform.android) {
      return SizedBox.fromSize(size: logicalSize);
    }
    return SizedBox.fromSize(
      size: logicalSize,
      child: AndroidView(
        viewType: 'meta_banner_ad',
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
    final channel = MethodChannel('meta_banner_ad_$id');
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
