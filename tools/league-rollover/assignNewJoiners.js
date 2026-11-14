'use strict';

// Lightweight daily companion to rollover.js — assigns players who signed
// up mid-week (pendingJoin still true) into a Bronze room, and players
// returning after an inactivity prune back into their own tier, so a new
// signup waits at most ~24h to see a real room instead of up to 6 days
// for the next Monday rollover. Prefers topping up an existing
// under-capacity room over spinning up a new one, so a small (or lone)
// day's cohort doesn't end up stuck alone with no one to play against
// — see foldIntoExistingRooms below. Deliberately does NOT touch scoring,
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
const { assignRoomsForTier, boundsForTier, rejoinTier, ROOM_TIERS } = require('./assignRooms');

// Debug builds stamp isTestAccount: true at signup (see
// LeagueRepository.ensurePlayerDocument) — dev/test devices, not real
// players. There's no real uninstall detection to clean these up the
// moment testing actually ends (this app has no push-token
// infrastructure to build that on — see aluna_availability_service.dart
// for the sibling discussion), so instead: purge anything still flagged
// isTestAccount once it's old enough that it's clearly not a live
// testing session anymore. Runs before the pendingJoin sweep below so a
// stale test account never gets swept into a fresh room first.
const TEST_ACCOUNT_MAX_AGE_HOURS = 72;

async function pruneStaleTestAccounts(db) {
  const cutoff = new Date(Date.now() - TEST_ACCOUNT_MAX_AGE_HOURS * 60 * 60 * 1000);
  const snap = await db.collection('players').where('isTestAccount', '==', true).get();

  let pruned = 0;
  for (const doc of snap.docs) {
    const data = doc.data();
    const createdAt = data.createdAt;
    if (!createdAt || createdAt.toDate() > cutoff) continue;

    const scoresSnap = await doc.ref.collection('scores').listDocuments();
    for (const weekDoc of scoresSnap) {
      const modesSnap = await weekDoc.collection('modes').listDocuments();
      for (const modeDoc of modesSnap) await modeDoc.delete();
      await weekDoc.delete();
    }
    await doc.ref.delete();

    if (data.roomId) {
      await db.collection('leagueRooms').doc(data.roomId).update({
        memberUids: admin.firestore.FieldValue.arrayRemove(doc.id),
      });
    }
    pruned++;
  }
  console.log(`Pruned ${pruned} stale test account(s) (older than ${TEST_ACCOUNT_MAX_AGE_HOURS}h).`);
}

// Reinstall churn: a player who reinstalls (or clears app data) gets a
// fresh anonymous uid and a brand-new players/{uid} doc, orphaning the
// old one — it just sits there forever with no way to ever be reached
// again, quietly bloating the league (an extra body in the room, extra
// weight in size-based rebalancing) without ever playing again. The app
// stamps a per-device deviceId at signup (see DeviceIdService /
// LeagueRepository.ensurePlayerDocument) specifically so this job can
// spot that pattern: multiple player docs sharing the same device.
// Deletion only ever happens here, server-side — a client reporting a
// matching deviceId is not itself authorization to delete another
// player's account, so this can't be triggered client-side even in
// principle (see firestore.rules: players/{uid} delete is always false).
async function pruneDuplicateDeviceAccounts(db) {
  const snap = await db.collection('players').get();

  const byDevice = new Map();
  for (const doc of snap.docs) {
    const deviceId = doc.data().deviceId;
    if (!deviceId) continue;
    if (!byDevice.has(deviceId)) byDevice.set(deviceId, []);
    byDevice.get(deviceId).push(doc);
  }

  let pruned = 0;
  for (const [deviceId, docs] of byDevice.entries()) {
    if (docs.length < 2) continue;

    // Which doc is the live one? NOT simply the newest createdAt: restoring
    // a Google-linked account from Settings switches this install back to
    // its OLD uid after a fresh anonymous doc was already created, so
    // "newest createdAt wins" deleted the restored (often long-time, Gold)
    // account and kept the throwaway one. Prefer a Google-linked doc, then
    // the most recently played (lastActiveAt), then newest createdAt. A
    // missing timestamp sorts as oldest (epoch 0).
    const millis = (ts) => ts?.toMillis() ?? 0;
    docs.sort((a, b) => {
      const da = a.data();
      const db_ = b.data();
      return (Number(db_.linkedGoogle === true) - Number(da.linkedGoogle === true))
        || (millis(db_.lastActiveAt) - millis(da.lastActiveAt))
        || (millis(db_.createdAt) - millis(da.createdAt));
    });
    const [keep, ...rest] = docs;
    // A Google-linked account is never an orphan: it can always be signed
    // back into, so it's never pruned as a duplicate (two family members'
    // linked accounts on one shared phone both survive).
    const stale = rest.filter((d) => d.data().linkedGoogle !== true);
    if (stale.length === 0) continue;
    console.log(`Device ${deviceId}: keeping ${keep.id}, pruning ${stale.length} stale duplicate(s)`);

    for (const doc of stale) {
      const data = doc.data();
      const scoresSnap = await doc.ref.collection('scores').listDocuments();
      for (const weekDoc of scoresSnap) {
        const modesSnap = await weekDoc.collection('modes').listDocuments();
        for (const modeDoc of modesSnap) await modeDoc.delete();
        await weekDoc.delete();
      }
      await doc.ref.delete();

      if (data.roomId) {
        // .update() throws if the room doc doesn't exist (e.g. already
        // cleaned up, or a stale/bad roomId) — that's a real possibility
        // here, not a should-never-happen case, and one bad reference
        // shouldn't take down the rest of this run (and every other
        // pending player's assignment along with it, which is exactly
        // what happened the one time this wasn't guarded).
        try {
          await db.collection('leagueRooms').doc(data.roomId).update({
            memberUids: admin.firestore.FieldValue.arrayRemove(doc.id),
          });
        } catch (err) {
          console.warn(`Could not remove ${doc.id} from room ${data.roomId} (may not exist): ${err.message}`);
        }
      }
      pruned++;
    }
  }
  console.log(`Pruned ${pruned} duplicate-device account(s).`);
}

async function seatInRoom(db, roomRef, tier, uids, wasSize) {
  await roomRef.update({ memberUids: admin.firestore.FieldValue.arrayUnion(...uids) });
  const batch = db.batch();
  for (const uid of uids) {
    batch.set(db.collection('players').doc(uid), {
      tier, roomId: roomRef.id, pendingJoin: false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  }
  await batch.commit();
  console.log(`Folded ${uids.length} player(s) into existing ${tier} room ${roomRef.id} (was ${wasSize})`);
}

// A lone (or small) pending cohort shouldn't be stuck by itself in a
// brand-new room with no one to play against — top up whatever rooms of
// that tier already exist this week (both the Monday rollover's main rooms
// and earlier days' daily-cohort rooms) before ever creating a new one.
// Fills the smallest/loneliest rooms first, up to the tier's max.
//
// Bronze gets new entrants in real numbers, so once its rooms are full the
// overflow goes to fresh rooms. Silver/Gold only ever get returning
// players here (a handful at a time), and a fresh room of one returner
// would be a dead competition — so any overflow there squeezes into the
// tier's smallest existing room, slightly over max. Only when the tier has
// no rooms at all this week does it return uids for fresh rooms.
// Returns whichever uids still need a fresh room.
async function foldIntoExistingRooms(db, weekId, tier, uids) {
  const { max } = boundsForTier(tier);
  const roomsSnap = await db.collection('leagueRooms')
    .where('tier', '==', tier)
    .where('weekId', '==', weekId)
    .get();

  const rooms = roomsSnap.docs
    .map((d) => ({ ref: d.ref, size: (d.data().memberUids || []).length }))
    .sort((a, b) => a.size - b.size);

  let remaining = uids.slice();
  for (const room of rooms) {
    if (remaining.length === 0) break;
    if (room.size >= max) continue;
    const take = remaining.splice(0, max - room.size);
    await seatInRoom(db, room.ref, tier, take, room.size);
    room.size += take.length;
  }

  if (remaining.length > 0 && tier !== 'bronze' && rooms.length > 0) {
    rooms.sort((a, b) => a.size - b.size);
    await seatInRoom(db, rooms[0].ref, tier, remaining, rooms[0].size);
    remaining = [];
  }
  return remaining;
}

async function main() {
  const serviceAccountRaw = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (!serviceAccountRaw) throw new Error('FIREBASE_SERVICE_ACCOUNT env var is not set');
  admin.initializeApp({ credential: admin.credential.cert(JSON.parse(serviceAccountRaw)) });
  const db = admin.firestore();

  const now = new Date();
  const weekId = isoWeekId(currentWeekStartUtc(now));
  const dateKey = now.toISOString().slice(0, 10); // YYYY-MM-DD, UTC

  console.log(`Daily join run at ${now.toISOString()} — week ${weekId}, date ${dateKey}`);

  await pruneStaleTestAccounts(db);
  await pruneDuplicateDeviceAccounts(db);

  // New entrants are bronze; players parked by the inactivity prune kept
  // their tier (see rollover.js) and go back into it — see rejoinTier.
  const pendingSnap = await db.collection('players').where('pendingJoin', '==', true).get();
  const byTier = new Map(ROOM_TIERS.map((t) => [t, []]));
  for (const doc of pendingSnap.docs) byTier.get(rejoinTier(doc.data())).push(doc.id);
  console.log(`${pendingSnap.size} player(s) pending assignment: ${
    ROOM_TIERS.map((t) => `${t} ${byTier.get(t).length}`).join(', ')}`);

  if (pendingSnap.size === 0) {
    console.log('Nothing to do.');
    return;
  }

  let roomsCreated = 0;
  let playersInNewRooms = 0;
  for (const tier of ROOM_TIERS) {
    const pending = byTier.get(tier);
    if (pending.length === 0) continue;

    const uids = await foldIntoExistingRooms(db, weekId, tier, pending);
    if (uids.length === 0) continue;

    // Distinct seed from the weekly rollover's own room-numbering scheme
    // ({tier}_{weekId}_{i}) so today's ad-hoc cohort rooms can never
    // collide with rooms the Monday rollover created for this same week.
    const rooms = assignRoomsForTier(uids, `${weekId}_daily_${dateKey}_${tier}`, boundsForTier(tier));

    for (let i = 0; i < rooms.length; i++) {
      const roomId = `${tier}_${weekId}_daily_${dateKey}_${i}`;
      await db.collection('leagueRooms').doc(roomId).set({
        tier, weekId, memberUids: rooms[i],
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      roomsCreated++;
      playersInNewRooms += rooms[i].length;

      const batch = db.batch();
      for (const uid of rooms[i]) {
        batch.set(db.collection('players').doc(uid), {
          tier, roomId, pendingJoin: false,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      }
      await batch.commit();
    }
  }

  console.log(`Daily join complete: ${roomsCreated} new room(s) for ${playersInNewRooms} player(s); the rest folded into existing rooms.`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
