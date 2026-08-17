import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_bootstrap.dart';
import '../../../core/utils/league_scoring.dart';
import '../../../data/repositories/auth_repository.dart';

class LeagueMemberEntry {
  final String uid;
  final String nickname;
  final String countryCode;
  final int streak;
  final int score;
  final int worldChampionCount;

  const LeagueMemberEntry({
    required this.uid,
    required this.nickname,
    required this.countryCode,
    required this.streak,
    required this.score,
    required this.worldChampionCount,
  });
}

/// The current player's players/{uid} document, watched live — this is
/// what tells the League tab whether the player has a profile yet, is
/// waiting to be placed in a room, or belongs to an active room.
final playerDocProvider =
    StreamProvider.autoDispose<DocumentSnapshot<Map<String, dynamic>>?>((ref) {
  if (!firebaseAvailable) return const Stream.empty();
  final uid = ref.watch(uidProvider);
  if (uid == null) return const Stream.empty();
  return FirebaseFirestore.instance.collection('players').doc(uid).snapshots();
});

/// Fetches every member of a room, each member's current-week score total
/// (via a Firestore aggregation query, not a client-writable counter —
/// see league_repository.dart / firestore.rules for why), and sorts by
/// (score desc, streak desc) per the league tie-break rule. Re-fetched
/// whenever invalidated (pull-to-refresh, or on League tab entry) rather
/// than a fully live multi-listener merge — simpler, and standings don't
/// need sub-second freshness.
final leagueRoomMembersProvider =
    FutureProvider.autoDispose.family<List<LeagueMemberEntry>, String>((ref, roomId) async {
  if (!firebaseAvailable) return [];
  final db = FirebaseFirestore.instance;

  final roomSnap = await db.collection('leagueRooms').doc(roomId).get();
  final roomData = roomSnap.data();
  if (roomData == null) return [];
  final memberUids = List<String>.from(roomData['memberUids'] as List? ?? []);
  final weekId = isoWeekId(DateTime.now().toUtc());

  final entries = await Future.wait(memberUids.map((uid) async {
    final profileSnap = await db.collection('players').doc(uid).get();
    final profile = profileSnap.data();
    if (profile == null) return null;

    final modesRef =
        db.collection('players').doc(uid).collection('scores').doc(weekId).collection('modes');
    final agg = await modesRef.aggregate(sum('score')).get();
    final total = (agg.getSum('score') ?? 0).round();

    return LeagueMemberEntry(
      uid: uid,
      nickname: profile['nickname'] as String? ?? 'Player',
      countryCode: profile['countryCode'] as String? ?? 'US',
      streak: (profile['currentStreak'] as num?)?.toInt() ?? 0,
      score: total,
      worldChampionCount: (profile['worldChampionCount'] as num?)?.toInt() ?? 0,
    );
  }));

  final members = entries.whereType<LeagueMemberEntry>().toList();
  members.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : b.streak.compareTo(a.streak);
  });
  return members;
});
