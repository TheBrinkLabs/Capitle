import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_bootstrap.dart';
import '../../../data/repositories/auth_repository.dart';

class WeekHistoryEntry {
  final String weekId;
  final int score;
  final int streak;
  final int rank;
  final String tier;
  final int roomSize;
  final String outcome; // "promoted" | "relegated" | "stayed"

  const WeekHistoryEntry({
    required this.weekId,
    required this.score,
    required this.streak,
    required this.rank,
    required this.tier,
    required this.roomSize,
    required this.outcome,
  });

  factory WeekHistoryEntry.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return WeekHistoryEntry(
      weekId: doc.id,
      score: (d['score'] as num?)?.toInt() ?? 0,
      streak: (d['streak'] as num?)?.toInt() ?? 0,
      rank: (d['rank'] as num?)?.toInt() ?? 0,
      tier: d['tier'] as String? ?? 'bronze',
      roomSize: (d['roomSize'] as num?)?.toInt() ?? 0,
      outcome: d['outcome'] as String? ?? 'stayed',
    );
  }
}

/// The last 12 completed weeks (roughly a quarter) of league results —
/// written by the weekly rollover job, so this is durable across
/// reinstalls/devices, unlike the rest of Capitle's local-only stats.
final weekHistoryProvider = FutureProvider.autoDispose<List<WeekHistoryEntry>>((ref) async {
  if (!firebaseAvailable) return [];
  final uid = ref.watch(uidProvider);
  if (uid == null) return [];

  final snap = await FirebaseFirestore.instance
      .collection('players')
      .doc(uid)
      .collection('weekHistory')
      .orderBy(FieldPath.documentId, descending: true)
      .limit(12)
      .get();

  return snap.docs.map(WeekHistoryEntry.fromDoc).toList().reversed.toList();
});
