import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pending_score.dart';

/// Local queue of game results whose league submission hasn't been
/// confirmed on Firestore yet. Entries are added the moment a game ends
/// (before the network attempt, so an app kill mid-attempt can't lose one
/// either) and removed only once submitGameScore genuinely succeeds — see
/// GameStateNotifier._onGameOver and _flushPendingScores.
///
/// A player who reinstalls loses this queue along with everything else
/// local — same as the reinstall-loses-local-state tradeoff already
/// accepted throughout this app (see DeviceIdService, PlayerProfile's
/// lastShownWeekResultId). Nothing to do about that without server-side
/// infrastructure this app doesn't have.
class PendingScoreRepository {
  static const _prefKey = 'pending_scores';
  // A score more than this old is almost certainly for a week that has
  // already rolled over and can never be credited to the right week
  // again — drop it on load rather than let the queue grow forever with
  // entries that can never succeed.
  static const _maxAge = Duration(days: 21);

  final SharedPreferences _prefs;
  PendingScoreRepository(this._prefs);

  List<PendingScore> loadAll() {
    final raw = _prefs.getStringList(_prefKey);
    if (raw == null) return [];
    final cutoff = DateTime.now().toUtc().subtract(_maxAge);
    final scores = raw
        .map((s) {
          try {
            return PendingScore.fromJson(jsonDecode(s) as Map<String, dynamic>);
          } catch (_) {
            return null; // corrupt entry — drop it, never crash on it
          }
        })
        .whereType<PendingScore>()
        .where((s) => s.playedAt.isAfter(cutoff))
        .toList();
    return scores;
  }

  Future<void> _saveAll(List<PendingScore> scores) async {
    await _prefs.setStringList(_prefKey, scores.map((s) => jsonEncode(s.toJson())).toList());
  }

  Future<void> enqueue(PendingScore score) async {
    final scores = loadAll();
    // Replace rather than duplicate if this exact game (mode+day) is
    // already queued — shouldn't normally happen (the day's puzzle is
    // one-shot), but keeps the queue honest if it ever does.
    scores.removeWhere((s) => s.id == score.id);
    scores.add(score);
    await _saveAll(scores);
  }

  Future<void> remove(String id) async {
    final scores = loadAll()..removeWhere((s) => s.id == id);
    await _saveAll(scores);
  }
}
