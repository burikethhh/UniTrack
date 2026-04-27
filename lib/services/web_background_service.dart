import 'dart:js_interop';

/// Dart interop for web/bg_tracking.js
/// Activates Wake Lock + beforeunload beacon for background GPS on web.
class WebBackgroundService {
  static const _projectId = 'unitrack-sksu-app';

  /// Start background tracking helpers (Wake Lock + offline beacon).
  /// [authToken] is the Firebase Auth ID token for Firestore REST writes.
  static void start(String userId, String authToken) {
    _bgTrackingStart(
      userId.toJS,
      _projectId.toJS,
      authToken.toJS,
      ((JSNumber lat, JSNumber lng, JSNumber acc, JSNumber ts) {
        // onUpdate callback — currently unused because Dart's own
        // Geolocator stream already handles location forwarding.
      }).toJS,
    );
  }

  /// Update the cached auth token (call every ~50 min to stay fresh).
  static void updateToken(String token) {
    _bgTrackingUpdateToken(token.toJS);
  }

  /// Stop background tracking helpers.
  static void stop() {
    _bgTrackingStop();
  }

  /// Whether the JS-side background tracker is active.
  static bool get isActive {
    return _bgTrackingIsActive().toDart;
  }
}

@JS('_bgTrackingStart')
external void _bgTrackingStart(
  JSString userId,
  JSString projectId,
  JSString authToken,
  JSFunction onUpdate,
);

@JS('_bgTrackingUpdateToken')
external void _bgTrackingUpdateToken(JSString token);

@JS('_bgTrackingStop')
external void _bgTrackingStop();

@JS('_bgTrackingIsActive')
external JSBoolean _bgTrackingIsActive();
