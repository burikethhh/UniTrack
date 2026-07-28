/**
 * ISKSULARS TRACK - Firestore Seed Script
 * Seeds version data, API config, and update notifications.
 * 
 * Usage: node seed_firestore.js
 */

const admin = require('firebase-admin');
const path = require('path');

const serviceAccount = require(path.join(__dirname, 'service-account.json'));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'isksulars-track',
  storageBucket: 'isksulars-track.firebasestorage.app'
});

const db = admin.firestore();

const versions = [
  {
    versionName: '1.0.0',
    versionCode: 1,
    downloadUrl: 'https://github.com/burikethhh/UniTrack/releases/download/v1.0.0/UniTrack-v1.0.0.apk',
    releaseNotes: 'Initial release of ISKSULARS TRACK\n- Real-time faculty location tracking\n- Campus maps with 2D view\n- Student directory and search\n- Faculty availability status\n- Push notifications',
    isRequired: true,
    isActive: false,
    releaseDate: new Date('2025-10-01'),
    downloadCount: 0,
    fileSize: 75000000,
    minSupportedApiVersion: 1,
  },
  {
    versionName: '2.0.0',
    versionCode: 2,
    downloadUrl: 'https://github.com/burikethhh/UniTrack/releases/download/v2.0.0/unitrack-latest.apk',
    releaseNotes: 'Complete overhaul\n- 3D campus maps\n- Multi-campus support (7 campuses)\n- Student leader tracking\n- Organization system\n- Offline mode\n- Improved UI/UX',
    isRequired: false,
    isActive: false,
    releaseDate: new Date('2026-01-15'),
    downloadCount: 0,
    fileSize: 98000000,
    minSupportedApiVersion: 2,
  },
  {
    versionName: '2.0.1',
    versionCode: 3,
    downloadUrl: 'https://github.com/burikethhh/UniTrack/releases/download/v2.0.1/UniTrack-v2.0.1.apk',
    releaseNotes: 'New features\n- Walking directions\n- Faculty ping notifications\n- Quick messages\n- Auto-hide schedule\n- Background tracking improvements',
    isRequired: false,
    isActive: false,
    releaseDate: new Date('2026-02-01'),
    downloadCount: 0,
    fileSize: 98000000,
    minSupportedApiVersion: 2,
  },
  {
    versionName: '2.0.2',
    versionCode: 4,
    downloadUrl: 'https://github.com/burikethhh/UniTrack/releases/download/v2.0.2/UniTrack-v2.0.2.apk',
    releaseNotes: 'Bug fixes\n- Fixed login race condition on web\n- Fixed location accuracy issues\n- Improved offline cache reliability',
    isRequired: false,
    isActive: false,
    releaseDate: new Date('2026-02-15'),
    downloadCount: 0,
    fileSize: 98000000,
    minSupportedApiVersion: 2,
  },
  {
    versionName: '2.0.3',
    versionCode: 5,
    downloadUrl: 'https://github.com/burikethhh/UniTrack/releases/download/v2.0.3/UniTrack-v2.0.3.apk',
    releaseNotes: 'Download improvements\n- Fixed APK download progress\n- Added file size display\n- Improved error handling',
    isRequired: false,
    isActive: true,
    releaseDate: new Date('2026-03-01'),
    downloadCount: 0,
    fileSize: 98000000,
    minSupportedApiVersion: 2,
  },
];

async function seedVersions() {
  console.log('Seeding app_versions...\n');
  const batch = db.batch();
  const ref = db.collection('app_versions');

  for (const v of versions) {
    const snap = await ref.where('versionCode', '==', v.versionCode).get();
    if (!snap.empty) {
      console.log(`  SKIP  v${v.versionName} (code ${v.versionCode}) - already exists`);
      continue;
    }
    const doc = ref.doc();
    batch.set(doc, {
      ...v,
      releaseDate: admin.firestore.Timestamp.fromDate(v.releaseDate),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`  ADDED v${v.versionName} (code ${v.versionCode})`);
  }

  await batch.commit();
  console.log('Done.\n');
}

async function seedApiConfig() {
  console.log('Seeding config/api...\n');
  await db.collection('config').doc('api').set({
    currentApiVersion: 2,
    minSupportedApiVersion: 1,
    deprecatedApiVersions: [],
    features: {
      multiCampusSupport: true,
      locationSmoothing: true,
      connectivityMonitoring: true,
      passwordStrengthCheck: true,
    },
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
  console.log('Done.\n');
}

async function main() {
  try {
    await seedVersions();
    await seedApiConfig();

    // Show what's in the database now
    console.log('Verifying...');
    const snap = await db.collection('app_versions').orderBy('versionCode').get();
    snap.forEach(doc => {
      const d = doc.data();
      console.log(`  v${d.versionName} (code ${d.versionCode}) active=${d.isActive} required=${d.isRequired}`);
    });

    console.log('\nSeed complete!');
    process.exit(0);
  } catch (err) {
    console.error('Error:', err.message);
    process.exit(1);
  }
}

main();
