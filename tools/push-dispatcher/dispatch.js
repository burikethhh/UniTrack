/**
 * ISKSULARS TRACK — Push Notification Dispatcher
 *
 * Runs via GitHub Actions (cron every 2 min, free on public repos).
 * Reads unprocessed Firestore notifications, looks up each recipient's
 * FCM tokens, and sends push messages via Firebase Admin SDK.
 *
 * Spark-plan compatible — no Cloud Functions needed.
 */

const admin = require('firebase-admin');
const path = require('path');
const serviceAccountPath = process.env.SERVICE_ACCOUNT_PATH
  || path.resolve(__dirname, '..', 'service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(require(serviceAccountPath)),
});

const db = admin.firestore();
const PUSH_BATCH = 50;
const FCM_BATCH = 500;

async function dispatch() {
  console.log('Starting push dispatch...');

  // Fetch recent notifications.  Filter client-side for speed (only ~50 docs).
  const snap = await db
    .collection('notifications')
    .orderBy('createdAt', 'desc')
    .limit(PUSH_BATCH)
    .get();

  if (snap.empty) {
    console.log('No notifications found.');
    return { dispatched: 0, skipped: 0 };
  }

  let dispatched = 0;
  let skipped = 0;

  for (const doc of snap.docs) {
    const data = doc.data();

    // Skip already-sent notifications
    if (data._pushSent === true) { skipped++; continue; }

    const recipientId = data.recipientId;
    if (!recipientId) {
      await doc.ref.update({ _pushSent: true });
      skipped++;
      continue;
    }

    // Get recipient's FCM tokens
    const userDoc = await db.collection('users').doc(recipientId).get();
    const fcmTokens = userDoc.data()?.fcmTokens;
    if (!fcmTokens || !Array.isArray(fcmTokens) || fcmTokens.length === 0) {
      await doc.ref.update({ _pushSent: true });
      skipped++;
      continue;
    }

    // Build the FCM message
    const payload = {
      notification: {
        title: data.title || 'ISKSULARS TRACK',
        body: data.message || '',
      },
      data: {
        notificationId: doc.id,
        type: data.type || 'system',
        senderId: data.senderId || '',
        ...(data.data || {}),
      },
      webpush: {
        headers: {
          Urgency: data.type === 'lookingForYou' ? 'high' : 'normal',
        },
        notification: {
          icon: '/icons/Icon-192.png',
          badge: '/icons/Icon-72.png',
          requireInteraction: data.type === 'lookingForYou',
        },
      },
    };

    // Send to each token in batches
    try {
      for (let i = 0; i < fcmTokens.length; i += FCM_BATCH) {
        const chunk = fcmTokens.slice(i, i + FCM_BATCH);
        const response = await admin.messaging().sendEachForMulticast({
          tokens: chunk,
          notification: payload.notification,
          data: payload.data,
          webpush: payload.webpush,
        });

        response.responses.forEach((resp, idx) => {
          if (resp.success) {
            console.log(`OK: ${chunk[idx].slice(0, 12)}...`);
          } else {
            const code = resp.error?.code;
            console.warn(`FAIL: ${chunk[idx].slice(0, 12)}... ${code}`);
            if (
              code === 'messaging/invalid-registration-token' ||
              code === 'messaging/registration-token-not-registered'
            ) {
              try {
                db.collection('users').doc(recipientId).update({
                  fcmTokens: admin.firestore.FieldValue.arrayRemove(chunk[idx]),
                });
              } catch (_) {}
            }
          }
        });
      }
    } catch (err) {
      console.error(`ERROR sending to ${recipientId}: ${err.message}`);
      continue;
    }

    // Mark as sent
    await doc.ref.update({ _pushSent: true });
    dispatched++;
    console.log(`PUSHED to ${recipientId}`);
  }

  console.log(`Done: ${dispatched} dispatched, ${skipped} skipped.`);
  return { dispatched, skipped };
}

dispatch()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });