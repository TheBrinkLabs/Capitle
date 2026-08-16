'use strict';

const admin = require('firebase-admin');
const { isoWeekId, currentWeekStartUtc, addDays } = require('./isoWeek');
const { assignRoomsForTier } = require('./assignRooms');

// Platinum deliberately excluded for now — see the matching note by
// kActiveTiers in lib/features/league/widgets/league_tier_badge.dart.
// To bring it back, add 'platinum' here too.
const TIERS = ['bronze', 'silver', 'gold'];
const MODES = ['guessCountry', 'guessCapital', 'guessFlag', 'guessNeighbours', 'guessPopulation', 'guessOutline'];

function tierAbove(tier) {
  const i = TIERS.indexOf(tier);
  return i < TIERS.length - 1 ? TIERS[i + 1] : null;
}
function tierBelow(tier) {
  const i = TIERS.indexOf(tier);
  return i > 0 ? TIERS[i - 1] : null;
}

async function main() {
  const serviceAccountRaw = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (!serviceAccountRaw) throw new Error('FIREBASE_SERVICE_ACCOUNT env var is not set');
  admin.initializeApp({ credential: admin.credential.cert(JSON.parse(serviceAccountRaw)) });
  const db = admin.firestore();

  const now = new Date();
  // Triggered Monday 00:00 UTC — the week that "just ended" is the one
  // whose Monday was 7 days ago.
  const justEndedWeekStart = addDays(currentWeekStartUtc(now), -7);
  const justEndedWeekId = isoWeekId(justEndedWeekStart);
  const nextWeekId = isoWeekId(currentWeekStartUtc(now));

  console.log(`Rollover run at ${now.toISOString()} — closing ${justEndedWeekId}, opening ${nextWeekId}`);

  // ── Idempotency guard ────────────────────────────────────────────────
  const logRef = db.collection('leagueMeta').doc('rolloverLog').collection('weeks').doc(justEndedWeekId);
  const logSnap = await logRef.get();
  if (logSnap.exists && logSnap.data().status === 'completed') {
    console.log(`${justEndedWeekId} already rolled over — exiting.`);
    return;
  }
  await logRef.set({ status: 'in-progress', startedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });

  try {
    // ── 1. Score every room live during the week that just ended ───────
    const roomsSnap = await db.collection('leagueRooms').where('weekId', '==', justEndedWeekId).get();
    console.log(`Found ${roomsSnap.size} rooms for ${justEndedWeekId}`);

    /** @type {Record<string, {uid: string, tier: string}[]>} incoming pool per NEXT tier */
    const incomingPools = { bronze: [], silver: [], gold: [] };
    let playersProcessed = 0;

    for (const roomDoc of roomsSnap.docs) {
      const room = roomDoc.data();
      const tier = room.tier;
      const memberUids = room.memberUids || [];

      const scored = await Promise.all(memberUids.map(async (uid) => {
        const modesSnap = await db.collection('players').doc(uid)
          .collection('scores').doc(justEndedWeekId).collection('modes').get();
        let total = 0;
        modesSnap.forEach((d) => { total += (d.data().score || 0); });

        const playerSnap = await db.collection('players').doc(uid).get();
        const streak = playerSnap.exists ? (playerSnap.data().currentStreak || 0) : 0;
        return { uid, score: total, streak };
      }));

      scored.sort((a, b) => (b.score - a.score) || (b.streak - a.streak));

      const promoteCount = tierAbove(tier) ? Math.min(3, scored.length) : 0;
      const relegateCount = tierBelow(tier) ? Math.min(3, Math.max(0, scored.length - promoteCount)) : 0;

      const batch = db.batch();
      scored.forEach((entry, i) => {
        const isPromoted = i < promoteCount;
        const isRelegated = i >= scored.length - relegateCount;
        const outcome = isPromoted ? 'promoted' : isRelegated ? 'relegated' : 'stayed';
        const nextTier = isPromoted ? tierAbove(tier) : isRelegated ? tierBelow(tier) : tier;

        const historyRef = db.collection('players').doc(entry.uid)
          .collection('weekHistory').doc(justEndedWeekId);
        batch.set(historyRef, {
          score: entry.score,
          streak: entry.streak,
          rank: i + 1,
          tier,
          roomId: roomDoc.id,
          roomSize: scored.length,
          outcome,
        });

        incomingPools[nextTier].push(entry.uid);
        playersProcessed++;
      });
      await batch.commit();
    }

    // ── 2. New entrants join Bronze only ────────────────────────────────
    const pendingSnap = await db.collection('players').where('pendingJoin', '==', true).get();
    pendingSnap.forEach((doc) => incomingPools.bronze.push(doc.id));
    console.log(`${pendingSnap.size} new entrants joining Bronze`);

    // ── 3. Assign new rooms per tier ────────────────────────────────────
    let roomsCreated = 0;
    for (const tier of TIERS) {
      const pool = incomingPools[tier];
      const rooms = assignRoomsForTier(pool, nextWeekId);
      for (let i = 0; i < rooms.length; i++) {
        const roomId = `${tier}_${nextWeekId}_${i}`;
        await db.collection('leagueRooms').doc(roomId).set({
          tier, weekId: nextWeekId, memberUids: rooms[i],
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        roomsCreated++;

        // Firestore batch writes cap at 500 — chunk defensively even
        // though a single room (max 19 members) never comes close.
        for (let c = 0; c < rooms[i].length; c += 450) {
          const chunk = rooms[i].slice(c, c + 450);
          const batch = db.batch();
          for (const uid of chunk) {
            batch.set(db.collection('players').doc(uid), {
              tier, roomId, pendingJoin: false,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
          }
          await batch.commit();
        }
      }
      console.log(`${tier}: ${pool.length} players -> ${rooms.length} room(s)`);
    }

    // ── 4. Update the authoritative "current week" pointer ──────────────
    const nextWeekStart = currentWeekStartUtc(now);
    const nextWeekEnd = addDays(nextWeekStart, 7);
    await db.collection('leagueMeta').doc('currentWeek').set({
      weekId: nextWeekId,
      weekStart: admin.firestore.Timestamp.fromDate(nextWeekStart),
      weekEnd: admin.firestore.Timestamp.fromDate(nextWeekEnd),
    });

    await logRef.set({
      status: 'completed',
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
      roomsCreated,
      playersProcessed,
    }, { merge: true });

    console.log(`Rollover complete: ${roomsCreated} rooms created, ${playersProcessed} players processed.`);
  } catch (err) {
    console.error('Rollover failed:', err);
    await logRef.set({
      status: 'failed',
      error: String((err && err.message) || err),
      failedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    process.exit(1);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
