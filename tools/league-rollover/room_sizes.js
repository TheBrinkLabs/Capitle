'use strict';
const admin = require('firebase-admin');
const serviceAccountRaw = process.env.FIREBASE_SERVICE_ACCOUNT;
admin.initializeApp({ credential: admin.credential.cert(JSON.parse(serviceAccountRaw)) });
const db = admin.firestore();

(async () => {
  const roomsSnap = await db.collection('leagueRooms').get();
  const rooms = roomsSnap.docs.map(d => ({ id: d.id, tier: d.data().tier, weekId: d.data().weekId, size: (d.data().memberUids || []).length }));
  rooms.sort((a, b) => a.tier.localeCompare(b.tier) || b.size - a.size);
  for (const r of rooms) console.log(`${r.tier.padEnd(8)} ${r.weekId.padEnd(14)} ${r.id.padEnd(30)} ${r.size} members`);
  process.exit(0);
})();
