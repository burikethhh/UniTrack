// Script to promote user to admin
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

// Initialize with application default credentials
initializeApp({
  projectId: 'boldiluxxx'
});

const db = getFirestore();

async function promoteToAdmin(email) {
  console.log(`🔍 Searching for user: ${email}`);
  
  try {
    const usersRef = db.collection('users');
    const snapshot = await usersRef.where('email', '==', email).get();
    
    if (snapshot.empty) {
      console.log('❌ No user found with that email');
      return;
    }
    
    for (const doc of snapshot.docs) {
      console.log(`📋 Found user: ${doc.id}`);
      console.log(`   Current role: ${doc.data().role}`);
      console.log(`   Name: ${doc.data().firstName} ${doc.data().lastName}`);
      
      await doc.ref.update({ role: 'admin' });
      console.log(`✅ Updated role to: admin`);
    }
    
    console.log('\n🎉 Done! You are now a Super Admin.');
    console.log('   Log in to the app to access the Super Admin Dashboard.');
  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

// Run
promoteToAdmin('christiankethaguacito@sksu.edu.ph');
