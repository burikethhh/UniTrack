// Script to promote user to admin via the Firebase Admin SDK.
//
// The Admin SDK bypasses all Firestore security rules — required because
// a normal client cannot update the `role` field.
//
// PREREQUISITES:
//   1. `tools/service-account.json` (download from Firebase Console →
//      Project settings → Service accounts → Generate new private key).
//   2. `npm install firebase-admin` in the tools/ directory.
//   3. Run: node tools/promote_admin.js [email]
//      (defaults to the hardcoded email below)
//
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const fs = require('fs');
const path = require('path');

const SERVICE_ACCOUNT_PATH = path.join(__dirname, 'service-account.json');

if (!fs.existsSync(SERVICE_ACCOUNT_PATH)) {
  console.error('❌ Service account key not found at: ' + SERVICE_ACCOUNT_PATH);
  console.error('   Download it from Firebase Console → Project settings → '
      + 'Service accounts → Generate new private key.');
  process.exit(1);
}

const serviceAccount = require('./service-account.json');

// Initialize with service account credentials.
initializeApp({
  credential: cert(serviceAccount),
  projectId: 'isksulars-track',
});

const db = getFirestore();

async function promoteToAdmin(email) {
  console.log(`🔍 Searching for user: ${email}`);

  try {
    const usersRef = db.collection('users');
    const snapshot = await usersRef.where('email', '==', email).get();

    if (snapshot.empty) {
      console.log('❌ No user found with that email');
      process.exit(1);
    }

    for (const doc of snapshot.docs) {
      console.log(`📋 Found user: ${doc.id}`);
      console.log(`   Current role: ${doc.data().role}`);
      console.log(`   Name: ${doc.data().firstName} ${doc.data().lastName}`);

      await doc.ref.update({ role: 'admin' });
      console.log(`✅ Updated role to: admin`);
    }

    console.log('\n🎉 Done! The user can now log in to the admin dashboard.');
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

// Run with command-line arg or default email
const targetEmail = process.argv[2] || 'christiankethaguacito@sksu.edu.ph';
promoteToAdmin(targetEmail);

