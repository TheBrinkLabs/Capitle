import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/repositories/league_repository.dart';
import '../../data/repositories/pending_score_repository.dart';

/// Retries every queued-but-unconfirmed score submission — called right
/// after a fresh submission succeeds (we already know connectivity is up)
/// and once on app startup (covers the far more common case: whatever
/// failed happened in a previous session entirely). Never throws; a
/// failure just leaves an entry queued for the next opportunity.
Future<void> flushPendingScores({
  required LeagueRepository leagueRepo,
  required PendingScoreRepository pendingRepo,
  required String uid,
}) async {
  for (final entry in pendingRepo.loadAll()) {
    try {
      await leagueRepo.submitGameScore(
        uid: uid,
        mode: entry.mode,
        won: entry.won,
        guessesUsed: entry.guessesUsed,
        score: entry.score,
        playedAt: entry.playedAt,
      );
      await pendingRepo.remove(entry.id);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        // Firestore rules forbid overwriting an existing score doc — this
        // means the original attempt actually succeeded (e.g. the app was
        // killed after the write landed but before the local dequeue
        // ran). The desired end state is already achieved either way.
        await pendingRepo.remove(entry.id);
      }
      // Any other Firestore error (offline, etc.) — leave it queued.
    } catch (_) {
      // Leave it queued — try again next opportunity.
    }
  }
}
