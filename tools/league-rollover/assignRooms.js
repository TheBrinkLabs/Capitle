'use strict';

const TARGET_SIZE = 10;
const MIN_SIZE = 7;
const MAX_SIZE = 14;

// Gold is the top tier — there's no competition-integrity cost to a
// promotion into it being "too easy" the way there would be for Bronze->
// Silver (nothing above it to over-dilute), so it deliberately runs on
// looser room bounds than the standard target-10/7-14 used everywhere
// else: consolidate into fewer, livelier rooms instead of spreading a
// small top-tier population across several thin ones. 17 or fewer stays
// one room; 18 splits into two 9s (18 is the first pool assignRoomsForTier
// can't fit under max=17, so the split lands exactly there — not an
// independently-chosen threshold). Shared by rollover.js and
// assignNewJoiners.js (which re-seats returning players mid-week).
const GOLD_ROOM_BOUNDS = { target: 15, min: 7, max: 17 };

/** Room bounds for a tier: Gold's looser ones, everyone else's defaults. */
function boundsForTier(tier) {
  return tier === 'gold' ? GOLD_ROOM_BOUNDS : { target: TARGET_SIZE, min: MIN_SIZE, max: MAX_SIZE };
}

// Keep in sync with rollover.js's TIERS (Platinum deliberately excluded).
const ROOM_TIERS = ['bronze', 'silver', 'gold'];

/**
 * Which tier a pendingJoin player should be seated in. Brand-new players
 * are created as bronze; a player parked by the inactivity prune keeps the
 * tier they'd earned (see rollover.js), so coming back after a break puts
 * them back where they were instead of all the way down in Bronze.
 * Anything unrecognised falls back to bronze.
 */
function rejoinTier(playerData) {
  const t = playerData && playerData.tier;
  return ROOM_TIERS.includes(t) ? t : 'bronze';
}

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
 * Buckets a tier's incoming player pool into rooms sized [min, max],
 * targeting `target` per room once a pool is big enough to split,
 * distributing any remainder across the first N rooms rather than leaving
 * a trailing undersized room. A pool at or below `max` becomes a single
 * room, even if under `min` — an accepted, unavoidable cold-start case
 * (never padded by borrowing from another tier, since that would break
 * skill-banding).
 *
 * Defaults to Bronze/Silver's bounds (target 10, 7-14 per room). Gold
 * deliberately uses looser bounds (see GOLD_ROOM_BOUNDS above) —
 * promotion pressure/skill-banding matters less once you're already at
 * the top tier, so consolidating into fewer, bigger rooms makes for a
 * livelier competition than spreading thin across several small ones.
 *
 * @param {string[]} incomingUids
 * @param {string} weekId used to seed the shuffle deterministically
 * @param {{target?: number, min?: number, max?: number}} [bounds]
 * @returns {string[][]} array of rooms (each an array of uids)
 */
function assignRoomsForTier(incomingUids, weekId, bounds = {}) {
  if (incomingUids.length === 0) return [];
  const target = bounds.target ?? TARGET_SIZE;
  const min = bounds.min ?? MIN_SIZE;
  const max = bounds.max ?? MAX_SIZE;

  const shuffled = seededShuffle(incomingUids, weekId);
  const n = shuffled.length;

  if (n <= max) return [shuffled];

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
  const isValid = (rooms) => rooms.every((r) => r.length >= min && r.length <= max);

  const guess = Math.max(1, Math.round(n / target));
  // A gap just above `max` is a genuine possibility: 1 room exceeds max,
  // 2 rooms falls under min per room, and no room count in between is
  // legal either — there is no way to satisfy [min, max] for every room
  // when n falls in [max+1, 2*min-1]. Try a small window of room counts
  // around the estimate; if genuinely none work, fall back to a single
  // room that runs over max rather than one that runs under min — an
  // oversized room is a much smaller departure from "one healthy
  // competition" than an undersized one.
  for (const candidate of [guess, guess - 1, guess + 1, guess - 2, guess + 2]) {
    if (candidate < 1) continue;
    const rooms = build(candidate);
    if (isValid(rooms)) return rooms;
  }
  return [shuffled];
}

module.exports = {
  assignRoomsForTier, boundsForTier, rejoinTier, GOLD_ROOM_BOUNDS, ROOM_TIERS, TARGET_SIZE, MIN_SIZE, MAX_SIZE,
};
