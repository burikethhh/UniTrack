// Firebase Cloud Messaging Service Worker
// Required for FCM web push notifications

importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyAY4CRN5-oadBrBfZ1mxHY36Y51AB3msCE',
  appId: '1:142302004772:web:03dad372375e7d67103ab1',
  messagingSenderId: '142302004772',
  projectId: 'unitrack-sksu-app',
  authDomain: 'unitrack-sksu-app.firebaseapp.com',
  storageBucket: 'unitrack-sksu-app.firebasestorage.app',
});

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage(function(payload) {
  const notificationTitle = payload.notification?.title || 'UniTrack';
  const notificationOptions = {
    body: payload.notification?.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: payload.data?.tag || 'unitrack-notification',
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});
