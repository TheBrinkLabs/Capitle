import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/ad_service.dart';

/// Triggers Unity's rewarded video ad for a clue — replaces an earlier
/// embedded-MREC "watch an ad" screen (a Wordle-style page with our own
/// always-visible "Get Clue" button, backed by Meta Audience Network's
/// MREC format). That format had genuinely near-zero real fill for this
/// app's traffic; Unity's rewarded format has been the one consistently
/// reliable ad type through this app's testing, and this slot was
/// already being preloaded (see ad_service.dart's RewardedAdSlot.clue)
/// without ever actually being used. A full-screen native rewarded ad
/// IS its own watch experience — no custom screen/timer needed on top
/// of it the way the MREC embed required.
///
/// Returns true only if the ad was watched to completion and the reward
/// was actually earned — false if it was dismissed early, or wasn't
/// ready to show at all (callers should NOT grant the clue in that case).
Future<bool> showClueRewardedAd(BuildContext context) {
  final completer = Completer<bool>();

  adService.showRewardedAd(
    RewardedAdSlot.clue,
    onReward: () {
      if (!completer.isCompleted) completer.complete(true);
    },
    onDismissedWithoutReward: () {
      if (!completer.isCompleted) completer.complete(false);
    },
    onNotReady: () {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ad isn't ready yet — try again in a moment.")),
        );
      }
      if (!completer.isCompleted) completer.complete(false);
    },
  );

  return completer.future;
}
