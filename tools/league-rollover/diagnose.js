'use strict';
const admin = require('firebase-admin');

async function main() {
  const serviceAccountRaw = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (!serviceAccountRaw) throw new Error('FIREBASE_SERVICE_ACCOUNT env var is not set');
  admin.initializeApp({ credential: admin.credential.cert(JSON.parse(serviceAccountRaw)) });
  const db = admin.firestore();

  const playersSnap = await db.collection('players').get();
  const roomsSnap = await db.collection('leagueRooms').get();

  console.log(`Total player docs: ${playersSnap.size}`);
  console.log(`Total league rooms: ${roomsSnap.size}`);

  // Group players by (nickname, countryCode) within the SAME room to find
  // likely reinstall-ghost duplicates.
  const playersById = new Map();
  playersSnap.forEach(doc => playersById.set(doc.id, doc.data()));

  let duplicateGroups = 0;
  let duplicateAccounts = 0;
  const examples = [];

  roomsSnap.forEach(roomDoc => {
    const room = roomDoc.data();
    const memberUids = room.memberUids || [];
    const byKey = new Map();
    for (const uid of memberUids) {
      const p = playersById.get(uid);
      if (!p) continue;
      const key = `${(p.nickname || '').trim().toLowerCase()}|${p.countryCode || ''}`;
      if (!byKey.has(key)) byKey.set(key, []);
      byKey.get(key).push({ uid, ...p });
    }
    for (const [key, group] of byKey.entries()) {
      if (group.length > 1) {
        duplicateGroups++;
        duplicateAccounts += group.length;
        examples.push({ roomId: roomDoc.id, tier: room.tier, nickname: key.split('|')[0], members: group.map(g => ({ uid: g.uid, streak: g.currentStreak, worldChampionCount: g.worldChampionCount })) });
      }
    }
  });

  console.log(`\nDuplicate nickname+country groups found (same room): ${duplicateGroups}`);
  console.log(`Total accounts involved in duplicates: ${duplicateAccounts}`);
  console.log(`\nExamples (up to 15):`);
  for (const ex of examples.slice(0, 15)) {
    console.log(JSON.stringify(ex));
  }
}

main().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
