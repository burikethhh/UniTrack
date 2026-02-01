/**
 * UniTrack Version Management Script
 * 
 * This script initializes the app_versions collection in Firestore
 * to enable in-app updates for older app versions.
 * 
 * Usage: node setup_versions.js
 * 
 * Prerequisites:
 * - Firebase Admin SDK
 * - Service account key file
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin
const serviceAccountPath = path.join(__dirname, '..', 'android', 'app', 'google-services.json');

// You'll need to download your service account key from Firebase Console
// For now, using the default credentials approach
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'unitrack-sksu-app',
  storageBucket: 'unitrack-sksu-app.firebasestorage.app'
});

const db = admin.firestore();

// Version history - oldest to newest
const versions = [
  {
    versionName: '1.0.0',
    versionCode: 100,
    downloadUrl: '', // Will be set when APK is uploaded
    releaseNotes: 'Initial release of UniTrack.\n- Real-time faculty location tracking\n- Student directory\n- Staff dashboard\n- Admin panel',
    isRequired: false,
    isActive: false, // Disabled - should update
    releaseDate: new Date('2025-12-01'),
    downloadCount: 0,
    fileSize: 0,
    minSupportedApiVersion: 1,
  },
  {
    versionName: '1.1.0',
    versionCode: 110,
    downloadUrl: '',
    releaseNotes: 'Bug fixes and improvements.\n- Fixed location tracking issues\n- Improved UI responsiveness\n- Better error handling',
    isRequired: false,
    isActive: false,
    releaseDate: new Date('2025-12-15'),
    downloadCount: 0,
    fileSize: 0,
    minSupportedApiVersion: 1,
  },
  {
    versionName: '1.5.0',
    versionCode: 150,
    downloadUrl: '',
    releaseNotes: 'Major update!\n- Multi-campus support (Isulan, Tacurong, ACCESS)\n- Enhanced map features\n- Performance improvements',
    isRequired: false,
    isActive: false,
    releaseDate: new Date('2026-01-01'),
    downloadCount: 0,
    fileSize: 0,
    minSupportedApiVersion: 1,
  },
  {
    versionName: '2.0.0',
    versionCode: 200,
    downloadUrl: '',
    releaseNotes: 'UniTrack 2.0 - Complete Overhaul!\n\n✨ New Features:\n- Animated splash screen\n- Enhanced location accuracy with GPS smoothing\n- Network connectivity monitoring\n- Password strength indicator\n- Better error messages\n\n🔧 Improvements:\n- Faster faculty refresh (5s intervals)\n- Adaptive location tracking\n- Improved UI/UX\n- Code optimization\n\n🐛 Bug Fixes:\n- Fixed location staleness detection\n- Fixed login validation issues\n- Various stability improvements',
    isRequired: true, // Required update for security and compatibility
    isActive: true,
    releaseDate: new Date('2026-02-01'),
    downloadCount: 0,
    fileSize: 0,
    minSupportedApiVersion: 2,
  },
];

async function setupVersions() {
  console.log('🚀 Setting up app versions in Firestore...\n');
  
  const batch = db.batch();
  const versionsRef = db.collection('app_versions');
  
  // First, check existing versions
  const existingSnapshot = await versionsRef.get();
  console.log(`📋 Found ${existingSnapshot.size} existing version(s)\n`);
  
  for (const version of versions) {
    // Check if version already exists
    const existingQuery = await versionsRef
      .where('versionCode', '==', version.versionCode)
      .get();
    
    if (!existingQuery.empty) {
      console.log(`⏭️  Version ${version.versionName} (${version.versionCode}) already exists, skipping...`);
      continue;
    }
    
    // Create new version document
    const docRef = versionsRef.doc();
    batch.set(docRef, {
      ...version,
      releaseDate: admin.firestore.Timestamp.fromDate(version.releaseDate),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    console.log(`✅ Added version ${version.versionName} (code: ${version.versionCode})`);
  }
  
  await batch.commit();
  console.log('\n🎉 Version setup complete!');
  
  // Display current versions
  console.log('\n📊 Current versions in database:');
  const finalSnapshot = await versionsRef.orderBy('versionCode', 'desc').get();
  
  console.log('─'.repeat(80));
  console.log('| Version Name | Version Code | Active | Required | Release Date        |');
  console.log('─'.repeat(80));
  
  finalSnapshot.forEach(doc => {
    const data = doc.data();
    const releaseDate = data.releaseDate?.toDate?.() || new Date();
    console.log(
      `| ${data.versionName.padEnd(12)} | ${String(data.versionCode).padEnd(12)} | ${(data.isActive ? 'Yes' : 'No').padEnd(6)} | ${(data.isRequired ? 'Yes' : 'No').padEnd(8)} | ${releaseDate.toISOString().split('T')[0]} |`
    );
  });
  console.log('─'.repeat(80));
}

async function createApiVersionConfig() {
  console.log('\n📝 Setting up API version configuration...\n');
  
  const configRef = db.collection('config').doc('api');
  
  const apiConfig = {
    currentApiVersion: 2,
    minSupportedApiVersion: 1,
    deprecatedApiVersions: [],
    features: {
      multiCampusSupport: true,
      locationSmoothing: true,
      connectivityMonitoring: true,
      passwordStrengthCheck: true,
    },
    endpoints: {
      // Legacy endpoints that older versions might use
      v1: {
        checkUpdate: '/api/v1/checkUpdate',
        getLocation: '/api/v1/location',
        status: 'active',
      },
      v2: {
        checkUpdate: '/api/v2/checkUpdate',
        getLocation: '/api/v2/location',
        status: 'active',
      },
    },
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  
  await configRef.set(apiConfig, { merge: true });
  console.log('✅ API configuration saved!');
}

async function createUpdateNotification() {
  console.log('\n📢 Creating update notification for all users...\n');
  
  const usersSnapshot = await db.collection('users').get();
  
  if (usersSnapshot.empty) {
    console.log('⚠️  No users found to notify');
    return;
  }
  
  const batch = db.batch();
  let count = 0;
  
  usersSnapshot.forEach(userDoc => {
    const notifRef = db.collection('notifications').doc();
    batch.set(notifRef, {
      recipientId: userDoc.id,
      title: '🎉 UniTrack 2.0 is Here!',
      body: 'A major update is available with enhanced location tracking, animated splash screen, and many improvements. Update now for the best experience!',
      type: 'app_update',
      data: {
        versionName: '2.0.0',
        versionCode: 200,
        isRequired: true,
      },
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    count++;
  });
  
  await batch.commit();
  console.log(`✅ Created update notification for ${count} user(s)`);
}

// Main execution
async function main() {
  try {
    await setupVersions();
    await createApiVersionConfig();
    await createUpdateNotification();
    
    console.log('\n✨ All setup complete! Users with older versions will now see update prompts.\n');
    console.log('📌 Next steps:');
    console.log('   1. Build a release APK: flutter build apk --release');
    console.log('   2. Upload the APK via the Admin Dashboard > Version Management');
    console.log('   3. The download URL will be automatically set');
    console.log('   4. Users will be prompted to update on their next app launch\n');
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

main();
