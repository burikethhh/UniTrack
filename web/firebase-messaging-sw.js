// Firebase Cloud Messaging Service Worker
// Required for FCM web push notifications

importScripts('https://www.gstatic.com/firebasejs/11.0.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/11.0.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBBpAsroGKwFelz0Xf4rvFzwvUl9Ht9wv8',
  appId: '1:568922390866:web:f2d09e42176dcb1b7a3a8b',
  messagingSenderId: '568922390866',
  projectId: 'isksulars-track',
  authDomain: 'isksulars-track.firebaseapp.com',
  storageBucket: 'isksulars-track.firebasestorage.app',
});

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage(function(payload) {
  const notificationTitle = payload.notification?.title || 'ISKSULARS TRACK';
  const notificationOptions = {
    body: payload.notification?.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: payload.data?.tag || 'isksulars-notification',
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// Handle notification click — focus or open the app window
self.addEventListener('notificationclick', function(event) {
  event.notification.close();

  const urlToOpen = new URL('/', self.location.origin).href;

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(clientList) {
      // If a window is already open, focus it
      for (let i = 0; i < clientList.length; i++) {
        const client = clientList[i];
        if (client.url.includes(self.location.origin) && 'focus' in client) {
          return client.focus();
        }
      }
      // Otherwise open a new window
      if (client.openWindow) {
        return client.openWindow(urlToOpen);
      }
    })
  );
});