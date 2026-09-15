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

async function main() {
  const serviceAccountRaw = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (!serviceAccountRaw) throw new Error('FIREBASE_SERVICE_ACCOUNT env var is not set');
  const gmailUser = process.env.GMAIL_USER;
  const gmailAppPassword = process.env.GMAIL_APP_PASSWORD;
  const toEmail = process.env.REPORT_TO_EMAIL || gmailUser;
  if (!gmailUser || !gmailAppPassword) throw new Error('GMAIL_USER / GMAIL_APP_PASSWORD env vars are not set');

  admin.initializeApp({ credential: admin.credential.cert(JSON.parse(serviceAccountRaw)) });
  const db = admin.firestore();

  const weekId = isoWeekId(new Date());
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
