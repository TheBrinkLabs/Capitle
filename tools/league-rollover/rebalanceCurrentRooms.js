'use strict';

// One-off (re-runnable) mid-week fix: after tightening assignRooms.js's
// target room size, existing rooms created under the old, larger bounds
// don't resize themselves until the next Monday rollover. This script
// re-buckets each tier's CURRENT-WEEK main rollover rooms (the
// `${tier}_${weekId}_${i}` rooms rollover.js creates) into fresh rooms
// sized per today's assignRoomsForTier — but only for tiers where at
// least one existing room already exceeds MAX_SIZE, so a tier that's
// already fine is left untouched.
//
// Deliberately does NOT touch the separate `${tier}_${weekId}_daily_*`
// cohort rooms assignNewJoiners.js creates for mid-week signups — those
// are intentionally kept apart from the main pool until the next real
// rollover (see assignNewJoiners.js's own comment on this).
//
// Only moves `roomId` on each player doc — scores live at
// players/{uid}/scores/{weekId}/modes/{mode}, keyed by uid+weekId only,
// never by roomId, so re-bucketing room membership cannot touch or lose
// any score data.

const admin = require('firebase-admin');
const { assignRoomsForTier, MAX_SIZE } = require('./assignRooms');

async function main() {
  const serviceAccountRaw = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (!serviceAccountRaw) throw new Error('FIREBASE_SERVICE_ACCOUNT env var is not set');
  admin.initializeApp({ credential: admin.credential.cert(JSON.parse(serviceAccountRaw)) });
  const db = admin.firestore();

  const metaSnap = await db.collection('leagueMeta').doc('currentWeek').get();
  const weekId = metaSnap.data().weekId;
  console.log(`Current week: ${weekId}`);

  const roomsSnap = await db.collection('leagueRooms').where('weekId', '==', weekId).get();
  const mainRoomsByTier = new Map();
  for (const doc of roomsSnap.docs) {
    if (doc.id.includes('_daily_')) continue;
    const tier = doc.data().tier;
    if (!mainRoomsByTier.has(tier)) mainRoomsByTier.set(tier, []);
    mainRoomsByTier.get(tier).push(doc);
  }

  for (const [tier, docs] of mainRoomsByTier.entries()) {
    const sizes = docs.map((d) => (d.data().memberUids || []).length);
    const needsRebalance = sizes.some((s) => s > MAX_SIZE);
    console.log(`${tier}: ${docs.length} room(s), sizes [${sizes.join(', ')}] — ${needsRebalance ? 'rebalancing' : 'already fine, skipping'}`);
    if (!needsRebalance) continue;

    const pool = docs.flatMap((d) => d.data().memberUids || []);
    const newRooms = assignRoomsForTier(pool, `${weekId}_rebalance`);
    console.log(`  ${pool.length} players -> ${newRooms.length} room(s): [${newRooms.map((r) => r.length).join(', ')}]`);

    // Delete old room docs first.
    const deleteBatch = db.batch();
    for (const d of docs) deleteBatch.delete(d.ref);
    await deleteBatch.commit();

    // Create new room docs + point each player at their new room.
    for (let i = 0; i < newRooms.length; i++) {
      const roomId = `${tier}_${weekId}_${i}`;
      await db.collection('leagueRooms').doc(roomId).set({
        tier, weekId, memberUids: newRooms[i],
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      const batch = db.batch();
      for (const uid of newRooms[i]) {
        batch.set(db.collection('players').doc(uid), {
          roomId, updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      }
      await batch.commit();
    }
  }

  console.log('Done.');
}

main().then(() => process.exit(0)).catch((err) => { console.error(err); process.exit(1); });
