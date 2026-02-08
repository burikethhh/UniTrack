// UniTrack Service Worker — minimal for PWA installability
const CACHE_NAME = 'unitrack-v1';

// Install: cache the app shell
self.addEventListener('install', function(event) {
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME).then(function(cache) {
      return cache.addAll([
        './',
        './index.html',
        './manifest.json',
        './favicon.png',
        './icons/Icon-192.png',
        './icons/Icon-512.png'
      ]);
    })
  );
});

// Activate: clean up old caches
self.addEventListener('activate', function(event) {
  event.waitUntil(
    caches.keys().then(function(names) {
      return Promise.all(
        names.filter(function(name) { return name !== CACHE_NAME; })
             .map(function(name) { return caches.delete(name); })
      );
    }).then(function() { return self.clients.claim(); })
  );
});

// URLs that should NEVER be intercepted by the service worker
// (Firebase Auth, Firestore, Cloud Functions, etc.)
function shouldPassthrough(url) {
  return url.includes('googleapis.com') ||
         url.includes('firebaseapp.com') ||
         url.includes('firebaseio.com') ||
         url.includes('firebase') ||
         url.includes('identitytoolkit') ||
         url.includes('securetoken') ||
         url.includes('cloudfunctions') ||
         url.includes('firestore') ||
         url.includes('google.com') ||
         url.includes('gstatic.com');
}

// Fetch: network-first, but skip Firebase/auth requests entirely
self.addEventListener('fetch', function(event) {
  // Let Firebase & auth requests go straight to network — never cache or intercept
  if (shouldPassthrough(event.request.url)) {
    return;
  }

  // Only handle GET requests for app shell assets
  if (event.request.method !== 'GET') {
    return;
  }

  event.respondWith(
    fetch(event.request).catch(function() {
      return caches.match(event.request);
    })
  );
});
