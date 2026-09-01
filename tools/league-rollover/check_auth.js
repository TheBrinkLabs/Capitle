'use strict';
const admin = require('firebase-admin');

async function main() {
  admin.initializeApp({ credential: admin.credential.cert(JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)) });

  let total = 0;
  let anonymous = 0;
  let google = 0;
  const creationDates = [];
  let pageToken;
  do {
    const result = await admin.auth().listUsers(1000, pageToken);
    for (const user of result.users) {
      total++;
      if (user.providerData.length === 0) anonymous++;
      if (user.providerData.some(p => p.providerId === 'google.com')) google++;
      creationDates.push(new Date(user.metadata.creationTime));
    }
    pageToken = result.pageToken;
  } while (pageToken);

  creationDates.sort((a, b) => a - b);
  console.log(`Total Firebase Auth users: ${total}`);
  console.log(`  Anonymous: ${anonymous}, Google-linked: ${google}`);
  if (creationDates.length > 0) {
    console.log(`Oldest account: ${creationDates[0].toISOString()}`);
    console.log(`Newest account: ${creationDates[creationDates.length - 1].toISOString()}`);
    const now = Date.now();
    const last24h = creationDates.filter(d => now - d.getTime() < 24*60*60*1000).length;
    const last7d = creationDates.filter(d => now - d.getTime() < 7*24*60*60*1000).length;
    console.log(`Created in last 24h: ${last24h}`);
    console.log(`Created in last 7 days: ${last7d}`);
  }

  const db = admin.firestore();
  const playersSnap = await db.collection('players').get();
  console.log(`\nTotal players/ Firestore docs: ${playersSnap.size}`);
}
main().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
