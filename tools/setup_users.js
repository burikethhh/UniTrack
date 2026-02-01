const admin = require('firebase-admin');
const serviceAccount = require('./service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

const users = [
  {
    id: 'Etd8vDeifuUFX0HdFMgGiI5Zpjw2',
    email: 'christiankethaguacitoadmin@sksu.edu.ph',
    firstName: 'Christian Ketha',
    lastName: 'Guacito',
    role: 'admin',
    department: 'Administration',
    position: 'System Administrator',
    campusId: 'isulan',
    isActive: true,
    isTrackingEnabled: false,
    currentStatus: null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  {
    id: 'g9IT1ZyLf0YS7BcomfSrQz5lrmC3',
    email: 'christiankethaguacitostaff@sksu.edu.ph',
    firstName: 'Christian Ketha',
    lastName: 'Guacito',
    role: 'staff',
    department: 'College of Information and Computing Sciences',
    position: 'Instructor',
    campusId: 'isulan',
    isActive: true,
    isTrackingEnabled: false,
    currentStatus: 'Available',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  {
    id: 'vM1dF8FCAENrdjUulydVXrvjJ8z2',
    email: 'christiankethaguacito@sksu.edu.ph',
    firstName: 'Christian Ketha',
    lastName: 'Guacito',
    role: 'student',
    department: 'College of Information and Computing Sciences',
    position: null,
    campusId: 'isulan',
    isActive: true,
    isTrackingEnabled: false,
    currentStatus: null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),
  }
];

async function setupUsers() {
  console.log('Setting up user documents in Firestore...\n');
  
  for (const user of users) {
    const { id, ...userData } = user;
    try {
      await db.collection('users').doc(id).set(userData);
      console.log(`✓ Created user: ${userData.email} (${userData.role})`);
    } catch (error) {
      console.error(`✗ Error creating ${userData.email}:`, error.message);
    }
  }
  
  console.log('\nDone! All users have been set up.');
  process.exit(0);
}

setupUsers();
