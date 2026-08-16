'use strict';

// Lightweight daily companion to rollover.js — assigns players who signed
// up mid-week (pendingJoin still true) into a Bronze room together, so a
// new signup waits at most ~24h to see a real room instead of up to 6
// days for the next Monday rollover. Deliberately does NOT touch scoring,
// promotion, or relegation — those stay exclusively on the weekly cadence
// in rollover.js, which already sweeps any still-pending players itself
// as part of its own Monday run, so this script and that one never fight
// over the same player.
//
// Naturally idempotent: a re-run just finds fewer (or zero) pendingJoin
// players, since this script flips pendingJoin to false as it assigns
// them — no completion-log guard needed like rollover.js has for its
// week-scoped state transition.

const admin = require('firebase-admin');
const { isoWeekId, currentWeekStartUtc } = require('./isoWeek');
const { assignRoomsForTier } = require('./assignRooms');

async function main() {
  const serviceAccountRaw = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (!serviceAccountRaw) throw new Error('FIREBASE_SERVICE_ACCOUNT env var is not set');
  admin.initializeApp({ credential: admin.credential.cert(JSON.parse(serviceAccountRaw)) });
  const db = admin.firestore();

  const now = new Date();
  const weekId = isoWeekId(currentWeekStartUtc(now));
  const dateKey = now.toISOString().slice(0, 10); // YYYY-MM-DD, UTC

  console.log(`Daily join run at ${now.toISOString()} — week ${weekId}, date ${dateKey}`);

  const pendingSnap = await db.collection('players').where('pendingJoin', '==', true).get();
  const uids = pendingSnap.docs.map((d) => d.id);
  console.log(`${uids.length} player(s) pending Bronze assignment`);

  if (uids.length === 0) {
    console.log('Nothing to do.');
    return;
  }

  // Distinct seed from the weekly rollover's own room-numbering scheme
  // (bronze_{weekId}_{i}) so today's ad-hoc cohort rooms can never
  // collide with rooms the Monday rollover created for this same week.
  const rooms = assignRoomsForTier(uids, `${weekId}_daily_${dateKey}`);

  let roomsCreated = 0;
  for (let i = 0; i < rooms.length; i++) {
    const roomId = `bronze_${weekId}_daily_${dateKey}_${i}`;
    await db.collection('leagueRooms').doc(roomId).set({
      tier: 'bronze', weekId, memberUids: rooms[i],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    roomsCreated++;

    const batch = db.batch();
    for (const uid of rooms[i]) {
      batch.set(db.collection('players').doc(uid), {
        tier: 'bronze', roomId, pendingJoin: false,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    }
    await batch.commit();
  }

  console.log(`Daily join complete: ${roomsCreated} room(s) created for ${uids.length} player(s).`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
