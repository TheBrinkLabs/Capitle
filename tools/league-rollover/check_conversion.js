'use strict';
const admin = require('firebase-admin');
async function main() {
  admin.initializeApp({ credential: admin.credential.cert(JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)) });
  const db = admin.firestore();
  const playersSnap = await db.collection('players').get();
  const now = Date.now();
  let last24h = 0, last7d = 0;
  playersSnap.forEach(d => {
    const created = d.data().createdAt;
    if (!created) return;
    const age = now - created.toDate().getTime();
    if (age < 24*60*60*1000) last24h++;
    if (age < 7*24*60*60*1000) last7d++;
  });
  console.log(`Player docs created in last 24h: ${last24h}`);
  console.log(`Player docs created in last 7 days: ${last7d}`);
  console.log(`Total player docs: ${playersSnap.size}`);
}
main().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
