'use strict';
// Emails a per-tier league participation snapshot (rooms/members/how many
// have scored this week) — see .github/workflows/league-report.yml for the
// twice-weekly schedule. Run manually with:
//   FIREBASE_SERVICE_ACCOUNT=... GMAIL_USER=... GMAIL_APP_PASSWORD=... REPORT_TO_EMAIL=... node league_report.js
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');
const { isoWeekId } = require('./isoWeek.js');

const TIER_ORDER = ['bronze', 'silver', 'gold'];

async function buildReport(db, weekId) {
  const roomsSnap = await db.collection('leagueRooms').get();
  const rooms = roomsSnap.docs.map(d => d.data()).filter(r => r.weekId === weekId);

  const byTier = new Map();
  for (const r of rooms) {
    const tier = r.tier;
    if (!byTier.has(tier)) byTier.set(tier, { rooms: 0, members: 0, scored: 0 });
    const agg = byTier.get(tier);
    agg.rooms++;
    const memberUids = r.memberUids || [];
    agg.members += memberUids.length;

    const totals = await Promise.all(memberUids.map(async uid => {
      const modesSnap = await db.collection('players').doc(uid)
        .collection('scores').doc(weekId).collection('modes').get();
      let total = 0;
      modesSnap.forEach(d => { total += (d.data().score || 0); });
      return total;
    }));
    agg.scored += totals.filter(s => s > 0).length;
  }

  const tiers = [...byTier.keys()].sort((a, b) => TIER_ORDER.indexOf(a) - TIER_ORDER.indexOf(b));
  const rows = tiers.map(tier => ({ tier, ...byTier.get(tier) }));
  const total = rows.reduce((acc, r) => ({
    rooms: acc.rooms + r.rooms,
    members: acc.members + r.members,
    scored: acc.scored + r.scored,
  }), { rooms: 0, members: 0, scored: 0 });

  return { rows, total };
}

function renderText({ weekId, rows, total }) {
  const lines = [`Capitle league snapshot — week ${weekId}`, ''];
  const pad = (s, n) => String(s).padEnd(n);
  lines.push(`${pad('Tier', 8)} ${pad('Rooms', 6)} ${pad('Members', 8)} With points`);
  for (const r of rows) {
    lines.push(`${pad(r.tier, 8)} ${pad(r.rooms, 6)} ${pad(r.members, 8)} ${r.scored}`);
  }
  lines.push('-'.repeat(40));
  lines.push(`${pad('TOTAL', 8)} ${pad(total.rooms, 6)} ${pad(total.members, 8)} ${total.scored}`);
  return lines.join('\n');
}

function renderHtml({ weekId, rows, total }) {
  const row = (tier, rooms, members, scored, bold) => `
    <tr${bold ? ' style="font-weight:bold;border-top:2px solid #333;"' : ''}>
      <td style="padding:6px 14px;text-align:left;">${tier}</td>
      <td style="padding:6px 14px;text-align:right;">${rooms}</td>
      <td style="padding:6px 14px;text-align:right;">${members}</td>
      <td style="padding:6px 14px;text-align:right;">${scored}</td>
    </tr>`;
  const body = rows.map(r => row(r.tier[0].toUpperCase() + r.tier.slice(1), r.rooms, r.members, r.scored)).join('');
  const totalRow = row('Total', total.rooms, total.members, total.scored, true);
  return `
    <h2 style="font-family:sans-serif;">Capitle league snapshot — week ${weekId}</h2>
    <table style="border-collapse:collapse;font-family:sans-serif;font-size:14px;">
      <thead>
        <tr style="border-bottom:2px solid #333;">
          <th style="padding:6px 14px;text-align:left;">Tier</th>
          <th style="padding:6px 14px;text-align:right;">Rooms</th>
          <th style="padding:6px 14px;text-align:right;">Members</th>
          <th style="padding:6px 14px;text-align:right;">With points</th>
        </tr>
      </thead>
      <tbody>${body}${totalRow}</tbody>
    </table>`;
}

// GitHub Actions' scheduled crons are UTC-only and "best effort" — they can
// (and, observed in practice, sometimes do) fire 1-3+ hours late during busy
// periods. Two things follow from that:
//   1. The window each target maps to has to be generous, not an exact
//      minute/hour match, or a late firing just silently misses it.
//   2. Because the workflow schedules TWO cron entries per target (one for
//      BST, one for GMT — see the workflow file), a delayed firing of the
//      "wrong" entry can land inside the same window as the "right" one and
//      cause a genuine duplicate send. The dedupe check below (keyed by
//      week + target, stored in Firestore) is what actually prevents that —
//      the window alone can't.
const TARGETS = [
  { key: 'wed', weekday: 'Wed', hourMin: 19, hourMax: 23 },
  { key: 'sun', weekday: 'Sun', hourMin: 17, hourMax: 23 },
];

function ukLocalParts(date) {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Europe/London',
    weekday: 'short',
    hour: '2-digit',
    hour12: false,
  }).formatToParts(date);
  return {
    weekday: parts.find(p => p.type === 'weekday').value,
    hour: parseInt(parts.find(p => p.type === 'hour').value, 10),
  };
}

function matchTarget(date) {
  const { weekday, hour } = ukLocalParts(date);
  return TARGETS.find(t => t.weekday === weekday && hour >= t.hourMin && hour <= t.hourMax) || null;
}

async function main() {
  const serviceAccountRaw = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (!serviceAccountRaw) throw new Error('FIREBASE_SERVICE_ACCOUNT env var is not set');
  const gmailUser = process.env.GMAIL_USER;
  const gmailAppPassword = process.env.GMAIL_APP_PASSWORD;
  const toEmail = process.env.REPORT_TO_EMAIL || gmailUser;
  if (!gmailUser || !gmailAppPassword) throw new Error('GMAIL_USER / GMAIL_APP_PASSWORD env vars are not set');

  const isManual = process.env.GITHUB_EVENT_NAME === 'workflow_dispatch';
  const now = new Date();
  const target = matchTarget(now);
  const { weekday, hour } = ukLocalParts(now);

  if (!isManual && !target) {
    console.log(`Not within a scheduled report window (UK local time: ${weekday} ${hour}:00) — skipping.`);
    return;
  }

  admin.initializeApp({ credential: admin.credential.cert(JSON.parse(serviceAccountRaw)) });
  const db = admin.firestore();

  const weekId = isoWeekId(now);
  const stateRef = db.collection('systemState').doc('leagueReportSchedule');

  if (!isManual) {
    const dedupeKey = `${weekId}-${target.key}`;
    const stateSnap = await stateRef.get();
    if (stateSnap.exists && stateSnap.data().lastSentKey === dedupeKey) {
      console.log(`Already sent for ${dedupeKey} — skipping duplicate (this is a second, delayed cron firing).`);
      return;
    }
    await stateRef.set({ lastSentKey: dedupeKey, sentAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
  }

  const report = await buildReport(db, weekId);

  const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: { user: gmailUser, pass: gmailAppPassword },
  });

  await transporter.sendMail({
    from: gmailUser,
    to: toEmail,
    subject: `Capitle league snapshot — week ${weekId}`,
    text: renderText({ weekId, ...report }),
    html: renderHtml({ weekId, ...report }),
  });

  console.log(renderText({ weekId, ...report }));
  console.log(`\nEmail sent to ${toEmail}`);
}

main().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
