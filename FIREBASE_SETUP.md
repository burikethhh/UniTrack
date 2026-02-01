# Firebase Configuration Guide

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add Project"
3. Enter project name: **UniTrack-SKSU**
4. Disable Google Analytics (optional, for simplicity)
5. Click "Create Project"

## Step 2: Enable Authentication

1. In Firebase Console, go to **Build > Authentication**
2. Click "Get Started"
3. Go to **Sign-in method** tab
4. Enable **Email/Password** provider
5. Click "Save"

## Step 3: Set Up Cloud Firestore

1. Go to **Build > Firestore Database**
2. Click "Create Database"
3. Choose **Start in test mode** (for development)
4. Select a region closest to you (e.g., asia-southeast1)
5. Click "Enable"

### Firestore Security Rules (Production)

Replace the default rules with:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }
    
    // Locations collection
    match /locations/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }
    
    // Departments collection
    match /departments/{deptId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
                   get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
  }
}
```

## Step 4: Register Android App

1. In Firebase Console, click the **Android** icon
2. Enter package name: `com.sksu.unitrack`
3. Enter app nickname: **UniTrack Android**
4. (Optional) Enter SHA-1 for debugging
5. Click "Register app"
6. Download `google-services.json`
7. Place the file in: `android/app/google-services.json`
8. Click "Continue" through remaining steps

## Step 5: Register Web App (Optional)

1. In Firebase Console, click the **Web** icon (</> )
2. Enter app nickname: **UniTrack Web**
3. Click "Register app"
4. Copy the Firebase config object
5. Update `web/index.html` with the config

### Web Configuration

Add this script in `web/index.html` before `</body>`:

```html
<script src="https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/10.7.1/firebase-auth-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/10.7.1/firebase-firestore-compat.js"></script>
<script>
  const firebaseConfig = {
    apiKey: "YOUR_API_KEY",
    authDomain: "YOUR_PROJECT_ID.firebaseapp.com",
    projectId: "YOUR_PROJECT_ID",
    storageBucket: "YOUR_PROJECT_ID.appspot.com",
    messagingSenderId: "YOUR_MESSAGING_SENDER_ID",
    appId: "YOUR_APP_ID"
  };
  firebase.initializeApp(firebaseConfig);
</script>
```

## Step 6: Add Initial Data

### Create Departments

In Firestore, create a `departments` collection with these documents:

```
Document ID: IT
{
  "name": "College of Information Technology",
  "shortName": "IT",
  "building": "IT Building",
  "isActive": true
}

Document ID: Engineering
{
  "name": "College of Engineering",
  "shortName": "Engr",
  "building": "Engineering Building",
  "isActive": true
}

Document ID: BusinessAdmin
{
  "name": "College of Business Administration",
  "shortName": "CBA",
  "building": "Business Building",
  "isActive": true
}

Document ID: Education
{
  "name": "College of Education",
  "shortName": "Educ",
  "building": "Education Building",
  "isActive": true
}

Document ID: Arts
{
  "name": "College of Arts & Sciences",
  "shortName": "CAS",
  "building": "Arts & Sciences Building",
  "isActive": true
}
```

### Create Admin Account

1. Register through the app with role "Staff"
2. In Firestore, find the user document
3. Change `role` field to `admin`
4. Restart the app to access admin features

## Troubleshooting

### "FirebaseApp not initialized"
- Ensure `google-services.json` is in `android/app/`
- Run `flutter clean` and `flutter pub get`

### "Permission denied" errors
- Check Firestore Security Rules
- Ensure user is authenticated

### Location not working
- Grant location permissions on device
- Enable GPS/Location services

---

Once Firebase is configured, the app will be fully functional!
