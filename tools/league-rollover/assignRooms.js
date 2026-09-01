'use strict';

const TARGET_SIZE = 10;
const MIN_SIZE = 7;
const MAX_SIZE = 14;

/** Deterministic seeded shuffle (mulberry32) so a re-run with the same
 * weekId (e.g. after a failed run is retried) produces identical room
 * assignments — important for the idempotency guard in rollover.js. */
function seededShuffle(array, seed) {
  let h = 0;
  for (let i = 0; i < seed.length; i++) h = (Math.imul(h, 31) + seed.charCodeAt(i)) | 0;
  let state = h >>> 0 || 1;
  const rand = () => {
    state |= 0; state = (state + 0x6d2b79f5) | 0;
    let t = Math.imul(state ^ (state >>> 15), 1 | state);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  const result = array.slice();
  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(rand() * (i + 1));
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}

/**
 * Buckets a tier's incoming player pool into rooms of 7-14, distributing
 * any remainder across the first N rooms rather than leaving a trailing
 * undersized room. A pool at or below MAX_SIZE becomes a single room, even
 * if under MIN_SIZE — an accepted, unavoidable cold-start case (never
 * padded by borrowing from another tier, since that would break
 * skill-banding).
 *
 * @param {string[]} incomingUids
 * @param {string} weekId used to seed the shuffle deterministically
 * @returns {string[][]} array of rooms (each an array of uids)
 */
function assignRoomsForTier(incomingUids, weekId) {
  if (incomingUids.length === 0) return [];
  const shuffled = seededShuffle(incomingUids, weekId);
  const n = shuffled.length;

  if (n <= MAX_SIZE) return [shuffled];

  const build = (rooms) => {
    const base = Math.floor(n / rooms);
    const remainder = n % rooms;
    const out = [];
    let idx = 0;
    for (let i = 0; i < rooms; i++) {
      const size = base + (i < remainder ? 1 : 0);
      out.push(shuffled.slice(idx, idx + size));
      idx += size;
    }
    return out;
  };
  const isValid = (rooms) => rooms.every((r) => r.length >= MIN_SIZE && r.length <= MAX_SIZE);

  const guess = Math.max(1, Math.round(n / TARGET_SIZE));
  // n=20..23 is a genuine gap: 1 room exceeds MAX_SIZE, 2 rooms falls
  // under MIN_SIZE per room, and no room count in between is legal
  // either — there is no way to satisfy [MIN_SIZE, MAX_SIZE] for every
  // room when n falls in [MAX_SIZE+1, 2*MIN_SIZE-1]. Try a small window
  // of room counts around the estimate; if genuinely none work, fall
  // back to a single room that runs over MAX_SIZE rather than one that
  // runs under MIN_SIZE — an oversized room is a much smaller departure
  // from "one healthy competition" than an undersized one.
  for (const candidate of [guess, guess - 1, guess + 1, guess - 2, guess + 2]) {
    if (candidate < 1) continue;
    const rooms = build(candidate);
    if (isValid(rooms)) return rooms;
  }
  return [shuffled];
}

module.exports = { assignRoomsForTier, TARGET_SIZE, MIN_SIZE, MAX_SIZE };
