import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/league_scoring.dart';
import '../models/game_models.dart';

final leagueRepositoryProvider = Provider<LeagueRepository>((ref) {
  return LeagueRepository(FirebaseFirestore.instance);
});

class LeagueRepository {
  final FirebaseFirestore _db;
  LeagueRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _players => _db.collection('players');

  String currentWeekId() => isoWeekId(DateTime.now().toUtc());

  String _dateKeyUtc(DateTime utc) =>
      '${utc.year.toString().padLeft(4, '0')}${utc.month.toString().padLeft(2, '0')}${utc.day.toString().padLeft(2, '0')}';

  /// Creates the players/{uid} document the first time a player finishes
  /// profile setup (or skips it). Every new player starts pendingJoin=true,
  /// tier=bronze — the weekly rollover job is the only thing ever allowed
  /// to change tier/roomId/pendingJoin after this. A no-op if the document
  /// already exists (e.g. re-running setup from Settings).
  ///
  /// isTestAccount is stamped from kDebugMode at creation time — debug
  /// builds are dev/test devices, not real players, and without real
  /// uninstall detection (this app has no push-token infrastructure to
  /// build that on) they'd otherwise sit in the production league
  /// forever like any other player. The daily join job deletes accounts
  /// flagged this way after 72h — see assignNewJoiners.js.
  Future<void> ensurePlayerDocument({
    required String uid,
    required String nickname,
    required String countryCode,
    String? deviceId,
  }) async {
    final ref = _players.doc(uid);
    final snap = await ref.get();
    if (snap.exists) return;
    await ref.set({
      'nickname': nickname,
      'nicknameLower': nickname.toLowerCase(),
      'countryCode': countryCode,
      'currentStreak': 0,
      'tier': 'bronze',
      'roomId': null,
      'pendingJoin': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'linkedGoogle': false,
      'isTestAccount': kDebugMode,
      // Reinstall-churn cleanup signal — see DeviceIdService's doc comment.
      // Only ever set here, at creation; the actual duplicate-account
      // deletion runs server-side in the daily rollover job (never from
      // the client — deleting another player's doc needs to be a trusted,
      // audited action, not something a client can trigger by just
      // reporting a matching device ID).
      if (deviceId != null) 'deviceId': deviceId,
    });
  }

  Future<void> syncProfile({
    required String uid,
    required String nickname,
    required String countryCode,
  }) async {
    await _players.doc(uid).update({
      'nickname': nickname,
      'nicknameLower': nickname.toLowerCase(),
      'countryCode': countryCode,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> syncStreak({required String uid, required int streak}) async {
    await _players.doc(uid).update({
      'currentStreak': streak,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markLinkedGoogle(String uid) async {
    await _players.doc(uid).update({
      'linkedGoogle': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getPlayer(String uid) =>
      _players.doc(uid).get();

  /// This player's recorded result for [weekId] — written by rollover.js
  /// to players/{uid}/weekHistory/{weekId} at the end of that week (score,
  /// rank, tier they played in, roomSize, and outcome:
  /// 'promoted'/'relegated'/'stayed'). A plain single-document read, not a
  /// query — deliberately, so it needs no Firestore index (an orderBy-based
  /// "give me the latest one" query does, and fails hard without one).
  /// Returns null if that week never rolled over for this player (e.g.
  /// they joined after it ended, or the rollover hasn't run yet).
  Future<Map<String, dynamic>?> weekResult(String uid, String weekId) async {
    final doc = await _players.doc(uid).collection('weekHistory').doc(weekId).get();
    return doc.data();
  }

  /// This player's current-week league score total, summed live from
  /// Firestore (not a client cache) — used to capture a guaranteed-
  /// accurate "before" baseline just prior to submitting today's first
  /// score, so LeagueRankReveal never has to infer it after the fact.
  Future<int> myWeeklyScoreTotal(String uid) async {
    final weekId = currentWeekId();
    final modesRef = _players.doc(uid).collection('scores').doc(weekId).collection('modes');
    final agg = await modesRef.aggregate(sum('score')).get();
    return (agg.getSum('score') ?? 0).round();
  }

  /// Writes this game's result to players/{uid}/scores/{weekId}/modes/{modeDocId}.
  /// The document ID is deterministic (mode + today's date) and security
  /// rules forbid update/delete — a duplicate submission for the same
  /// day+mode is rejected by Firestore itself rather than needing app-level
  /// dedup logic.
  Future<void> submitGameScore({
    required String uid,
    required GameMode mode,
    required bool won,
    required int guessesUsed,
    required int score,
  }) async {
    final weekId = currentWeekId();
    final dateKey = _dateKeyUtc(DateTime.now().toUtc());
    final modeDocId = '${mode.name}_$dateKey';

    await _players
        .doc(uid)
        .collection('scores')
        .doc(weekId)
        .collection('modes')
        .doc(modeDocId)
        .set({
      'mode': mode.name,
      'dateKey': dateKey,
      'won': won,
      'guessesUsed': guessesUsed,
      'score': score,
      'weekId': weekId,
      'submittedAt': FieldValue.serverTimestamp(),
    });

    // Distinct from 'updatedAt' (which the weekly rollover script also
    // touches on every player it reassigns, win or lose, active or not —
    // so it can't be trusted as a genuine "last played" signal). This is
    // ONLY written when a real score is actually submitted, which is what
    // rollover.js's inactivity pruning depends on to tell a real player
    // on a break from an abandoned reinstall-ghost that will never play
    // again.
    final playerRef = _players.doc(uid);
    await playerRef.set({
      'lastActiveAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // A player pruned for inactivity (see rollover.js) is left "parked" —
    // roomId: null, pendingJoin: false — deliberately NOT re-queued
    // automatically, so the calendar ticking over doesn't undo the prune.
    // Actually playing again (this call) is the real "welcome back"
    // signal, so re-queue them for the next room-assignment sweep here.
    // (firestore.rules only allows this specific false->true flip when
    // the player is already in that exact parked state.)
    final snap = await playerRef.get();
    final data = snap.data();
    if (data != null && data['roomId'] == null && data['pendingJoin'] != true) {
      await playerRef.set({
        'pendingJoin': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }
}
