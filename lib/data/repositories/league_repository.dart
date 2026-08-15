import 'package:cloud_firestore/cloud_firestore.dart';
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
  Future<void> ensurePlayerDocument({
    required String uid,
    required String nickname,
    required String countryCode,
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
  }
}
