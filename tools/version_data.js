/**
 * UniTrack Version Seeder - Simple Version
 * 
 * This script uses the Firebase REST API to seed version data.
 * Run this from the Firebase Console or use the admin dashboard.
 * 
 * Alternative: Copy the JSON below directly into Firestore Console
 */

// Version data to add to Firestore 'app_versions' collection
const versions = [
  {
    versionName: "1.0.0",
    versionCode: 100,
    downloadUrl: "",
    releaseNotes: "Initial release of UniTrack.\n- Real-time faculty location tracking\n- Student directory\n- Staff dashboard\n- Admin panel",
    isRequired: false,
    isActive: false,
    releaseDate: { _seconds: Math.floor(new Date("2025-12-01").getTime() / 1000), _nanoseconds: 0 },
    downloadCount: 0,
    fileSize: 0,
    minSupportedApiVersion: 1
  },
  {
    versionName: "1.1.0",
    versionCode: 110,
    downloadUrl: "",
    releaseNotes: "Bug fixes and improvements.\n- Fixed location tracking issues\n- Improved UI responsiveness\n- Better error handling",
    isRequired: false,
    isActive: false,
    releaseDate: { _seconds: Math.floor(new Date("2025-12-15").getTime() / 1000), _nanoseconds: 0 },
    downloadCount: 0,
    fileSize: 0,
    minSupportedApiVersion: 1
  },
  {
    versionName: "1.5.0",
    versionCode: 150,
    downloadUrl: "",
    releaseNotes: "Major update!\n- Multi-campus support (Isulan, Tacurong, ACCESS)\n- Enhanced map features\n- Performance improvements",
    isRequired: false,
    isActive: false,
    releaseDate: { _seconds: Math.floor(new Date("2026-01-01").getTime() / 1000), _nanoseconds: 0 },
    downloadCount: 0,
    fileSize: 0,
    minSupportedApiVersion: 1
  },
  {
    versionName: "2.0.0",
    versionCode: 200,
    downloadUrl: "",
    releaseNotes: "UniTrack 2.0 - Complete Overhaul!\n\n✨ New Features:\n- Animated splash screen\n- Enhanced location accuracy with GPS smoothing\n- Network connectivity monitoring\n- Password strength indicator\n- Better error messages\n\n🔧 Improvements:\n- Faster faculty refresh (5s intervals)\n- Adaptive location tracking\n- Improved UI/UX\n- Code optimization\n\n🐛 Bug Fixes:\n- Fixed location staleness detection\n- Fixed login validation issues\n- Various stability improvements",
    isRequired: true,
    isActive: true,
    releaseDate: { _seconds: Math.floor(new Date("2026-02-01").getTime() / 1000), _nanoseconds: 0 },
    downloadCount: 0,
    fileSize: 0,
    minSupportedApiVersion: 2
  }
];

// API config
const apiConfig = {
  currentApiVersion: 2,
  minSupportedApiVersion: 1,
  deprecatedApiVersions: [],
  features: {
    multiCampusSupport: true,
    locationSmoothing: true,
    connectivityMonitoring: true,
    passwordStrengthCheck: true
  }
};

console.log("================================================================================");
console.log("UniTrack Version Data");
console.log("================================================================================");
console.log("\nCopy the following data to your Firestore database:\n");
console.log("1. Collection: 'app_versions'");
console.log("   Add each version as a separate document:\n");

versions.forEach((v, i) => {
  console.log(`   Document ${i + 1} (v${v.versionName}):`);
  console.log(JSON.stringify(v, null, 2));
  console.log("");
});

console.log("================================================================================");
console.log("2. Collection: 'config', Document ID: 'api'");
console.log(JSON.stringify(apiConfig, null, 2));
console.log("================================================================================");
console.log("\nAlternatively, use the Admin Dashboard > Version Management to upload APKs.");
console.log("The version information will be created automatically when you upload.\n");
