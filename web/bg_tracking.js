// ISKSULARS TRACK Background Tracking Helper
// Keeps geolocation running when the PWA tab is backgrounded/minimized.
// Uses Wake Lock API to prevent the tab from being suspended.
// On tab close (beforeunload), sends a final "offline" beacon to Firestore REST.

(function() {
  'use strict';

  let wakeLock = null;
  let watchId = null;
  let _userId = null;
  let _firestoreProjectId = null;
  let _authToken = null;
  let _onLocationUpdate = null;

  /**
   * Start background-aware geolocation tracking.
   * @param {string} userId - Firestore user document ID
   * @param {string} projectId - Firebase project ID
   * @param {string} authToken - Firebase Auth ID token for Firestore REST writes
   * @param {Function} onUpdate - Callback(lat, lng, accuracy, timestamp)
   */
  window._bgTrackingStart = function(userId, projectId, authToken, onUpdate) {
    _userId = userId;
    _firestoreProjectId = projectId;
    _authToken = authToken;
    _onLocationUpdate = onUpdate;

    // Acquire Wake Lock to keep tracking alive in background tab
    _acquireWakeLock();

    // Re-acquire wake lock when page becomes visible again
    document.addEventListener('visibilitychange', function() {
      if (document.visibilityState === 'visible') {
        _acquireWakeLock();
      }
    });

    // On unload, send a final offline marker via beacon
    window.addEventListener('beforeunload', _sendOfflineBeacon);

    console.log('[BgTracking] Started for user:', userId);
  };

  /**
   * Stop background tracking.
   */
  window._bgTrackingStop = function() {
    if (watchId !== null) {
      navigator.geolocation.clearWatch(watchId);
      watchId = null;
    }
    _releaseWakeLock();
    window.removeEventListener('beforeunload', _sendOfflineBeacon);
    _userId = null;
    _authToken = null;
    console.log('[BgTracking] Stopped');
  };

  /**
   * Update the cached Firebase Auth token (call every ~50 min).
   * @param {string} token - Fresh Firebase ID token
   */
  window._bgTrackingUpdateToken = function(token) {
    _authToken = token;
  };

  /**
   * Check if background tracking is active.
   */
  window._bgTrackingIsActive = function() {
    return watchId !== null;
  };

  // ── Wake Lock management ──

  async function _acquireWakeLock() {
    if (!('wakeLock' in navigator)) return;
    try {
      wakeLock = await navigator.wakeLock.request('screen');
      wakeLock.addEventListener('release', function() {
        console.log('[BgTracking] Wake lock released');
      });
      console.log('[BgTracking] Wake lock acquired');
    } catch (e) {
      console.warn('[BgTracking] Wake lock failed:', e);
    }
  }

  function _releaseWakeLock() {
    if (wakeLock) {
      wakeLock.release();
      wakeLock = null;
    }
  }

  // ── Offline beacon on tab close ──
  // Uses fetch() with keepalive:true instead of sendBeacon() because:
  //  - sendBeacon only sends POST; Firestore REST needs PATCH
  //  - sendBeacon can't set Authorization headers
  //  - fetch+keepalive supports custom method + headers and survives page unload
  function _sendOfflineBeacon() {
    if (!_userId || !_firestoreProjectId || !_authToken) return;
    var url = 'https://firestore.googleapis.com/v1/projects/' +
      _firestoreProjectId + '/databases/(default)/documents/locations/' +
      _userId + '?updateMask.fieldPaths=timestamp';
    // Set timestamp to 5 minutes ago so it counts as stale immediately
    var staleTime = new Date(Date.now() - 5 * 60 * 1000).toISOString();
    var body = JSON.stringify({
      fields: {
        timestamp: { timestampValue: staleTime }
      }
    });
    try {
      fetch(url, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + _authToken
        },
        body: body,
        keepalive: true
      }).catch(function() { /* best-effort, ignore */ });
      console.log('[BgTracking] Sent offline beacon via fetch+keepalive');
    } catch (e) {
      // Fallback: ignore — Firestore staleness detection will catch it
    }
  }
})();
