// UniTrack Service Worker — aggressive auto-updating PWA cache manager
// ──────────────────────────────────────────────────────────
// IMPORTANT: Bump BUILD_ID on each deploy to auto-bust caches.
const BUILD_ID = '__BUILD_20260408v3__';
const CACHE_NAME = 'unitrack-' + BUILD_ID;

// App shell files to cache (kept minimal for fast install)
const APP_SHELL = [
  './',
  './index.html',
  './manifest.json',
  './favicon.png',
  './icons/Icon-192.png',
  './icons/Icon-512.png'
];

// ── Install: cache the app shell, immediately take over ──
self.addEventListener('install', function(event) {
  console.log('[SW] Installing version:', BUILD_ID);
  // Don't wait for old tabs — activate immediately
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME).then(function(cache) {
      return Promise.allSettled(
        APP_SHELL.map(function(url) {
          return cache.add(url).catch(function(err) {
            console.warn('[SW] Failed to cache', url, err);
          });
        })
      );
    })
  );
});

// ── Activate: purge ALL old caches, claim clients, force reload ──
self.addEventListener('activate', function(event) {
  console.log('[SW] Activating version:', BUILD_ID);
  event.waitUntil(
    caches.keys().then(function(names) {
      return Promise.all(
        names.filter(function(name) { return name !== CACHE_NAME; })
             .map(function(name) {
               console.log('[SW] Deleting old cache:', name);
               return caches.delete(name);
             })
      );
    }).then(function() {
      return self.clients.claim();
    }).then(function() {
      // Notify every open tab to reload with the new version
      return self.clients.matchAll({ type: 'window' }).then(function(clients) {
        clients.forEach(function(client) {
          client.postMessage({ type: 'SW_UPDATED', version: BUILD_ID });
        });
      });
    })
  );
});

// URLs that should NEVER be intercepted by the service worker
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
         url.includes('gstatic.com') ||
         url.includes('version.json') ||
         url.includes('maplibre') ||
         url.includes('tile.openstreetmap.org') ||
         url.includes('arcgisonline.com') ||
         url.includes('maptiler.com') ||
         url.includes('demotiles.maplibre.org');
}

// Critical app resources that must always bypass the HTTP cache
function isCriticalAsset(url) {
  return url.includes('main.dart.js') ||
         url.includes('flutter_bootstrap.js') ||
         url.includes('version.json');
}

// ── Fetch: network-first, with no-cache on navigation requests ──
self.addEventListener('fetch', function(event) {
  // Let Firebase/auth/API/map-tile requests go straight to network
  if (shouldPassthrough(event.request.url)) return;
  if (event.request.method !== 'GET') return;

  // For navigation requests (HTML pages), always go to network with
  // cache-busting to guarantee the fresh app shell on every load.
  if (event.request.mode === 'navigate') {
    event.respondWith(
      fetch(event.request, { cache: 'no-store' }).then(function(response) {
        if (response.ok) {
          var clone = response.clone();
          caches.open(CACHE_NAME).then(function(c) { c.put(event.request, clone); });
        }
        return response;
      }).catch(function() {
        return caches.match(event.request);
      })
    );
    return;
  }

  // For critical Flutter assets (main.dart.js, bootstrap), always bust
  // the HTTP cache so updates are picked up on every reload.
  if (isCriticalAsset(event.request.url)) {
    event.respondWith(
      fetch(event.request, { cache: 'no-store' }).then(function(response) {
        if (response.ok) {
          var clone = response.clone();
          caches.open(CACHE_NAME).then(function(c) { c.put(event.request, clone); });
        }
        return response;
      }).catch(function() {
        return caches.match(event.request);
      })
    );
    return;
  }

  // For other assets (JS, CSS, images), use network-first
  event.respondWith(
    fetch(event.request).then(function(response) {
      if (response.ok) {
        var responseClone = response.clone();
        caches.open(CACHE_NAME).then(function(cache) {
          cache.put(event.request, responseClone);
        });
      }
      return response;
    }).catch(function() {
      return caches.match(event.request);
    })
  );
});

// ── Message handler: allow page to request cache clear ──
self.addEventListener('message', function(event) {
  if (event.data === 'SKIP_WAITING') {
    self.skipWaiting();
  }
  if (event.data === 'CLEAR_ALL_CACHES') {
    caches.keys().then(function(names) {
      return Promise.all(names.map(function(n) { return caches.delete(n); }));
    }).then(function() {
      self.clients.matchAll({ type: 'window' }).then(function(clients) {
        clients.forEach(function(client) {
          client.postMessage({ type: 'CACHES_CLEARED' });
        });
      });
    });
  }
});
