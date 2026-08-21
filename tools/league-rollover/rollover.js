'use strict';

const admin = require('firebase-admin');
const { isoWeekId, currentWeekStartUtc, addDays } = require('./isoWeek');
const { assignRoomsForTier } = require('./assignRooms');

// Platinum deliberately excluded for now — see the matching note by
// kActiveTiers in lib/features/league/widgets/league_tier_badge.dart.
// To bring it back, add 'platinum' here too.
const TIERS = ['bronze', 'silver', 'gold'];
const MODES = ['guessCountry', 'guessCapital', 'guessFlag', 'guessNeighbours', 'guessPopulation', 'guessOutline'];

// A player who hasn't submitted a single score in this long doesn't get
// carried into a new room next week — this is what actually cleans up
// reinstall "ghost" identities (an orphaned anonymous UID superseded by a
// fresh one stops submitting scores forever the moment that happens) as
// well as genuinely inactive players, without needing real uninstall
// detection (which this app has no infrastructure for — see
// lib/core/utils/aluna_availability_service.dart's sibling discussion).
// Two weekly cycles' worth of grace — long enough that someone on a
// short break isn't punished, short enough that ghosts don't linger.
const INACTIVITY_DAYS = 14;

function isInactive(playerData, now) {
  const reference = playerData.lastActiveAt || playerData.createdAt;
  if (!reference) return false; // defensive — shouldn't happen, never prune on missing data
  const ageMs = now.getTime() - reference.toDate().getTime();
  return ageMs > INACTIVITY_DAYS * 24 * 60 * 60 * 1000;
}

function tierAbove(tier) {
  const i = TIERS.indexOf(tier);
  return i < TIERS.length - 1 ? TIERS[i + 1] : null;
}
function tierBelow(tier) {
  const i = TIERS.indexOf(tier);
  return i > 0 ? TIERS[i - 1] : null;
}

// Promotion/relegation zone size scales with room size instead of a flat
// 3 — a flat 3 in, say, a 3-player room means the WHOLE room moves at
// once (everyone is simultaneously "top 3" and "bottom 3"), which isn't
// a meaningful result when there's nobody left to have actually beaten.
// Below 5 players, nobody moves at all; scales up to the original flat-3
// behaviour once a room reaches a normal size (rooms target 12-19
// members — see assignRooms.js).
function zoneSize(roomSize) {
  return Math.min(3, Math.floor(roomSize * 0.2));
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

    // Rank-1 finisher from every top-tier room this week (there may be
    // more than one room once a tier outgrows MAX_SIZE) — the single
    // best of these becomes the week's World Champion, decided after
    // every room has been scored below.
    const topTierCandidates = [];

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
        const exists = playerSnap.exists;
        const streak = exists ? (playerSnap.data().currentStreak || 0) : 0;
        const inactive = exists && isInactive(playerSnap.data(), now);
        return { uid, score: total, streak, exists, inactive };
      }));

      scored.sort((a, b) => (b.score - a.score) || (b.streak - a.streak));

      if (!tierAbove(tier) && scored.length > 0 && scored[0].exists && !scored[0].inactive) {
        topTierCandidates.push({ ...scored[0], roomId: roomDoc.id });
      }

      const promoteCount = tierAbove(tier) ? zoneSize(scored.length) : 0;
      const relegateCount = tierBelow(tier) ? Math.min(zoneSize(scored.length), Math.max(0, scored.length - promoteCount)) : 0;

      const batch = db.batch();
      let prunedThisRoom = 0;
      scored.forEach((entry, i) => {
        // A deleted player (e.g. a reinstall-ghost cleaned up manually
        // mid-week) has nothing left to update — skip entirely rather
        // than writing history for a doc that no longer exists or
        // resurrecting them into next week's room pool.
        if (!entry.exists) return;

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

        if (entry.inactive) {
          // Gone quiet for INACTIVITY_DAYS — don't carry them into a new
          // room. Deliberately pendingJoin: false here, NOT true — both
          // this script's own step 2 below and assignNewJoiners.js query
          // on pendingJoin == true, so setting it true would just sweep
          // them straight into a fresh room this same run, undoing the
          // prune entirely. Left fully "parked" instead; the app itself
          // flips pendingJoin back to true the next time they actually
          // submit a score (see LeagueRepository.submitGameScore), which
          // is the real "welcome back" signal, not just the calendar
          // ticking over.
          batch.set(db.collection('players').doc(entry.uid), {
            tier: 'bronze', roomId: null, pendingJoin: false,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });
          prunedThisRoom++;
        } else {
          incomingPools[nextTier].push(entry.uid);
        }
        playersProcessed++;
      });
      if (prunedThisRoom > 0) console.log(`${roomDoc.id}: pruned ${prunedThisRoom} inactive player(s)`);
      await batch.commit();
    }

    // ── World Champion: best rank-1 finisher across every top-tier room ──
    let worldChampionUid = null;
    if (topTierCandidates.length > 0) {
      topTierCandidates.sort((a, b) => (b.score - a.score) || (b.streak - a.streak));
      const champion = topTierCandidates[0];
      worldChampionUid = champion.uid;

      await db.collection('players').doc(champion.uid)
        .collection('weekHistory').doc(justEndedWeekId)
        .set({ isWorldChampion: true }, { merge: true });
      await db.collection('players').doc(champion.uid).set({
        worldChampionCount: admin.firestore.FieldValue.increment(1),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      console.log(`World Champion for ${justEndedWeekId}: ${champion.uid} (score ${champion.score}, room ${champion.roomId})`);
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
      worldChampionUid,
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
