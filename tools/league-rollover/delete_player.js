'use strict';
const admin = require('firebase-admin');

async function main() {
  const uid = process.argv[2];
  if (!uid) throw new Error('Usage: node delete_player.js <uid>');
  admin.initializeApp({ credential: admin.credential.cert(JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)) });
  const db = admin.firestore();

  const playerRef = db.collection('players').doc(uid);
  const playerSnap = await playerRef.get();
  if (!playerSnap.exists) {
    console.log(`No player doc for ${uid} — nothing to delete.`);
    return;
  }
  const roomId = playerSnap.data().roomId;
  console.log(`Deleting player ${uid} (nickname=${playerSnap.data().nickname}, roomId=${roomId})`);

  // Delete the scores subcollection (players/{uid}/scores/{weekId}/modes/*).
  const scoresSnap = await playerRef.collection('scores').listDocuments();
  for (const weekDoc of scoresSnap) {
    const modesSnap = await weekDoc.collection('modes').listDocuments();
    for (const modeDoc of modesSnap) await modeDoc.delete();
    await weekDoc.delete();
  }

  await playerRef.delete();
  console.log('Player doc deleted.');

  if (roomId) {
    await db.collection('leagueRooms').doc(roomId).update({
      memberUids: admin.firestore.FieldValue.arrayRemove(uid),
    });
    console.log(`Removed ${uid} from leagueRooms/${roomId}.memberUids`);
  }
}
main().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
