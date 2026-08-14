import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, kIsWeb, visibleForTesting;
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// permission_handler has no web support — only import on non-web
import 'package:permission_handler/permission_handler.dart' as ph
    if (dart.library.html) 'package:permission_handler/permission_handler.dart';
import '../models/location_model.dart';
import '../models/user_model.dart';
import '../core/constants/app_constants.dart';

/// Permission outcome for location access — separates the permission decision
/// from the side effect of opening settings, so the UI layer can show a
/// rationale dialog first.
enum LocationPermissionResult {
  granted,
  denied,
  permanentlyDenied,
  serviceDisabled,
}

/// Location tracking configuration for better accuracy
class LocationConfig {
  /// Minimum accuracy in meters to accept a GPS reading
  static const double minAccuracyMeters = 30.0;

  /// Distance filter for GPS stream (meters)
  static const double distanceFilterMeters = 1.0;
  
  /// Movement detection threshold (meters)
  static const double movementThreshold = 0.5;
  
  /// Stale location threshold (seconds) — guards the GPS heartbeat.
  /// If no real GPS reading arrives in this window the heartbeat stops
  /// refreshing so the location naturally goes stale.
  static const int staleThresholdSeconds = 90;
  
  /// Unified heartbeat interval (seconds).
  /// A single timer polls at this cadence and decides what to do based on
  /// current state (manual-pin refresh / fallback GPS read / nothing).
  /// Replaces the old 3-timer setup which caused redundant GPS wakeups.
  static const int unifiedTickSeconds = 5;
  
  /// Heartbeat interval for manual pin mode (seconds)
  static const int manualPinHeartbeatIntervalSec = 20;
  
  /// Number of readings to average for smoothing
  static const int smoothingWindowSize = 5;

}

/// Location Service for ISKSULARS TRACK
class LocationService {
  final FirebaseFirestore _firestore;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _unifiedTimer; // Single timer replacing heartbeat + movement + pin
  LocationModel? _lastLocation;
  Position? _previousPosition; // For movement detection
  String? _currentUserId;
  bool _isMoving = false;
  bool _isManualPinMode = false; // Track if user is in manual pin mode
  Function(LocationModel)? _onLocationUpdate;
  String? _currentStatus;
  String? _currentQuickMessage;
  DateTime? _statusExpiresAt;
  LocationVisibilityScope _visibilityScope = LocationVisibilityScope.campusOnly;
  Future<void> _locationWriteQueue = Future<void>.value();
  DateTime? _lastManualPinRefresh; // Tracks when the manual pin was last refreshed
  
  // Position history for smoothing (Kalman-like filtering)
  final List<Position> _positionHistory = [];
  DateTime? _lastFirestoreUpdate;
  DateTime? _lastGpsTimestamp; // When the last real GPS reading arrived
  int _consecutiveBadReadings = 0;

  /// Default constructor - uses Firebase and Geolocator instances
  LocationService()
      : _firestore = FirebaseFirestore.instance;

  /// Testable constructor - allows dependency injection
  @visibleForTesting
  LocationService.testable({
    FirebaseFirestore? firestore,
    GeolocatorPlatform? geolocator,
  })  : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Check if currently tracking location
  bool get isTracking => _positionSubscription != null;

  /// Check if in manual pin mode
  bool get isManualPinMode => _isManualPinMode;
  
  /// Check location permission WITHOUT opening settings as a side effect.
  /// Returns a result enum so the UI layer can decide whether to call
  /// [openSettingsForPermission] (e.g., after showing a rationale dialog).
  Future<LocationPermissionResult> checkPermission() async {
    if (kIsWeb) {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return permission == LocationPermission.whileInUse ||
             permission == LocationPermission.always
          ? LocationPermissionResult.granted
          : LocationPermissionResult.denied;
    }
    
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return LocationPermissionResult.serviceDisabled;
    
    final status = await ph.Permission.locationWhenInUse.status;
    if (status.isGranted) return LocationPermissionResult.granted;
    if (status.isPermanentlyDenied) return LocationPermissionResult.permanentlyDenied;
    return LocationPermissionResult.denied;
  }

  /// Attempt to request permission (does not open system settings).
  Future<LocationPermissionResult> requestPermission() async {
    if (kIsWeb) {
      var permission = await Geolocator.requestPermission();
      return permission == LocationPermission.whileInUse ||
             permission == LocationPermission.always
          ? LocationPermissionResult.granted
          : LocationPermissionResult.denied;
    }
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return LocationPermissionResult.serviceDisabled;
    
    final status = await ph.Permission.locationWhenInUse.request();
    if (status.isGranted) return LocationPermissionResult.granted;
    if (status.isPermanentlyDenied) return LocationPermissionResult.permanentlyDenied;
    return LocationPermissionResult.denied;
  }

  /// Open system settings (caller should show a rationale dialog first).
  Future<void> openSettingsForPermission() async {
    if (kIsWeb) {
      // Browsers do not expose an application settings page. The user must
      // change the permission from the browser's address-bar controls.
      return;
    }
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }
    await ph.openAppSettings();
  }

  /// Backwards-compatible permission check that mirrors the old behavior
  /// (requests permission, then opens settings if still denied).
  /// Prefer [checkPermission] / [requestPermission] / [openSettingsForPermission]
  /// for new call sites.
  Future<bool> checkAndRequestPermission() async {
    var result = await checkPermission();
    if (result == LocationPermissionResult.granted) return true;
    if (result == LocationPermissionResult.denied) {
      result = await requestPermission();
      if (result == LocationPermissionResult.granted) return true;
    }
    if (result == LocationPermissionResult.denied ||
        result == LocationPermissionResult.permanentlyDenied ||
        result == LocationPermissionResult.serviceDisabled) {
      await openSettingsForPermission();
    }
    // Re-check after settings
    return (await checkPermission()) == LocationPermissionResult.granted;
  }
  
  /// Get current position
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await checkPermission();
      if (hasPermission != LocationPermissionResult.granted) return null;
      
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Error getting position: $e');
      return null;
    }
  }
  
  /// Check if position is within campus bounds using point-in-polygon algorithm
  /// Now supports multi-campus with campusId parameter
  bool isWithinCampus(double latitude, double longitude, {String? campusId}) {
    // Get the boundary for the specified campus (or default)
    final List<List<double>> polygon;
    if (campusId != null) {
      final boundary = AppConstants.getCampusBoundary(campusId);
      polygon = boundary ?? AppConstants.campusBoundaryPoints;
    } else {
      polygon = AppConstants.campusBoundaryPoints;
    }
    
    int intersections = 0;
    
    for (int i = 0; i < polygon.length; i++) {
      final j = (i + 1) % polygon.length;
      final xi = polygon[i][1]; // longitude
      final yi = polygon[i][0]; // latitude
      final xj = polygon[j][1]; // longitude
      final yj = polygon[j][0]; // latitude
      
      if (((yi > latitude) != (yj > latitude)) &&
          (longitude < (xj - xi) * (latitude - yi) / (yj - yi) + xi)) {
        intersections++;
      }
    }
    
    final isInside = intersections.isOdd;
    if (kDebugMode) {
      debugPrint('📍 Campus check (${campusId ?? 'default'}): ($latitude, $longitude) -> inside=$isInside');
    }
    return isInside;
  }
  
  /// Check if position is within ANY SKSU campus
  bool isWithinAnyCampus(double latitude, double longitude) {
    for (final campus in AppConstants.campusesData) {
      final campusId = campus['id'] as String;
      if (isWithinCampus(latitude, longitude, campusId: campusId)) {
        return true;
      }
    }
    return false;
  }
  
  /// Get which campus the position is in (returns campusId or null)
  String? getCampusForLocation(double latitude, double longitude) {
    for (final campus in AppConstants.campusesData) {
      final campusId = campus['id'] as String;
      if (isWithinCampus(latitude, longitude, campusId: campusId)) {
        return campusId;
      }
    }
    return null;
  }
  
  /// Set manual pin mode - when true, GPS updates won't overwrite the manual location
  void setManualPinMode(bool enabled) {
    _isManualPinMode = enabled;
    if (kDebugMode) debugPrint('📍 Manual Pin Mode: ${enabled ? "ENABLED" : "DISABLED"}');
  }
   
  /// Set manual location (bypasses GPS tracking)
  /// The unified timer will keep refreshing the pin's timestamp.
  Future<void> setManualLocation(String userId, LocationModel location) async {
    _isManualPinMode = true;
    _lastLocation = location;
    _currentUserId = userId;
    _lastManualPinRefresh = DateTime.now();
    await updateLocation(userId, location);
    _onLocationUpdate?.call(location);
    if (kDebugMode) debugPrint('📍 Manual pin set at (${location.latitude}, ${location.longitude})');
  }
  
  /// Calculate distance between two positions in meters
  double _calculateDistance(Position p1, Position p2) {
    const double earthRadius = 6371000; // meters
    final double lat1 = p1.latitude * math.pi / 180;
    final double lat2 = p2.latitude * math.pi / 180;
    final double dLat = (p2.latitude - p1.latitude) * math.pi / 180;
    final double dLon = (p2.longitude - p1.longitude) * math.pi / 180;
    
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  /// Start location tracking for faculty (GPS mode with movement detection)
  void startTracking({
    required String userId,
    required String? status,
    required String? quickMessage,
    String? campusId, // User's assigned campus for geofence checking
    DateTime? statusExpiresAt,
    LocationVisibilityScope visibilityScope = LocationVisibilityScope.campusOnly,
    required Function(LocationModel) onLocationUpdate,
  }) {
    _positionSubscription?.cancel();
    _unifiedTimer?.cancel();
    _isManualPinMode = false;
    _currentUserId = userId;
    _currentStatus = status;
    _currentQuickMessage = quickMessage;
    _statusExpiresAt = statusExpiresAt;
    _visibilityScope = visibilityScope;
    _onLocationUpdate = onLocationUpdate;
    _previousPosition = null;
    _isMoving = false;
    
    // GPS stream for position updates with optimized settings
    final LocationSettings locationSettings;
    if (kIsWeb) {
      // Web uses browser Geolocation API — no foreground notification needed
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );
    } else {
      // Android uses fused location provider with foreground notification
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: LocationConfig.distanceFilterMeters.toInt(),
        intervalDuration: Duration(seconds: LocationConfig.unifiedTickSeconds),
        forceLocationManager: false,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'ISKSULARS TRACK Location Sharing',
          notificationText: 'Sharing your location with students',
          enableWakeLock: true,
        ),
      );
    }
    
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) async {
      await _processGpsPosition(position);
    }, onError: (e) {
      if (kDebugMode) debugPrint('📍 GPS Stream Error: $e');
    });
    
    // Single unified timer replaces heartbeat + movement + manual-pin timers.
    // Every tick decides what to do based on current state, so there's
    // never more than one timer firing and never redundant GPS wakeups.
    _unifiedTimer = Timer.periodic(
      Duration(seconds: LocationConfig.unifiedTickSeconds),
      _onUnifiedTick,
    );
  }

  /// Single handler for the unified timer tick.
  /// Decides based on state whether to: refresh manual pin / fallback
  /// GPS read / heartbeat refresh / nothing.
  Future<void> _onUnifiedTick(Timer timer) async {
    if (_currentUserId == null || _lastLocation == null) return;

    // ── Manual-pin mode: refresh every manualPinHeartbeatIntervalSec
    if (_isManualPinMode) {
      final sinceRefresh = _lastManualPinRefresh != null
          ? DateTime.now().difference(_lastManualPinRefresh!).inSeconds
          : LocationConfig.manualPinHeartbeatIntervalSec;
      if (sinceRefresh >= LocationConfig.manualPinHeartbeatIntervalSec) {
        final refreshed = _lastLocation!.copyWith(timestamp: DateTime.now());
        _lastLocation = refreshed;
        _lastManualPinRefresh = DateTime.now();
        await updateLocation(_currentUserId!, refreshed);
        if (kDebugMode) debugPrint('📍 Manual-pin refresh: timestamp updated');
      }
      return;
    }

    // ── GPS mode: stale guard — only heartbeat-refresh when within window
    final gpsStale = _lastGpsTimestamp == null ||
        DateTime.now().difference(_lastGpsTimestamp!).inSeconds >
            LocationConfig.staleThresholdSeconds;

    if (gpsStale) {
      // GPS hasn't provided a real reading recently — do a fresh read.
      // This is the "movement timer fallback" + "heartbeat fresh read"
      // combined into a single attempt, gated by the staleness check so
      // we don't fire redundant getCurrentPosition calls when the stream
      // is active.
      if (kDebugMode) debugPrint('📍 Unified tick: stale GPS — attempting fresh read');
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
        await _processGpsPosition(position);
      } catch (e) {
        _consecutiveBadReadings++;
        if (kDebugMode) debugPrint('📍 Unified tick: fresh read failed: $e (bad: $_consecutiveBadReadings)');
        // Do not refresh the timestamp with an old position. The location must
        // become stale when the device cannot provide a valid GPS reading.
      }
      return;
    }

    // ── GPS is fresh — heartbeat refresh the timestamp (no GPS wakeup)
    final sinceFirestore = _lastFirestoreUpdate != null
        ? DateTime.now().difference(_lastFirestoreUpdate!).inSeconds
        : LocationConfig.staleThresholdSeconds;
    final interval = _isMoving ? 2 : 5; // movingUpdateIntervalSec / stationaryUpdateIntervalSec
    if (sinceFirestore >= interval) {
      final refreshed = _lastLocation!.copyWith(timestamp: DateTime.now());
      _lastLocation = refreshed;
      final written = await updateLocation(_currentUserId!, refreshed);
      if (written) _lastFirestoreUpdate = DateTime.now();
      if (kDebugMode) debugPrint('📍 Heartbeat refresh (withinCampus=${_lastLocation!.isWithinCampus})');
    }
  }
  
  /// Apply smoothing to position using weighted average of recent readings
  Position _smoothPosition(Position newPosition) {
    _positionHistory.add(newPosition);
    
    // Keep only recent positions
    while (_positionHistory.length > LocationConfig.smoothingWindowSize) {
      _positionHistory.removeAt(0);
    }
    
    if (_positionHistory.length < 2) return newPosition;
    
    // Weight recent readings more heavily
    double totalWeight = 0;
    double weightedLat = 0;
    double weightedLng = 0;
    double bestAccuracy = double.infinity;
    
    for (int i = 0; i < _positionHistory.length; i++) {
      final pos = _positionHistory[i];
      // More recent = higher weight, better accuracy = higher weight
      final recencyWeight = (i + 1) / _positionHistory.length;
      final accuracyWeight = pos.accuracy > 0 ? (100 / pos.accuracy).clamp(0.1, 2.0) : 1.0;
      final weight = recencyWeight * accuracyWeight;
      
      weightedLat += pos.latitude * weight;
      weightedLng += pos.longitude * weight;
      totalWeight += weight;
      
      if (pos.accuracy < bestAccuracy) bestAccuracy = pos.accuracy;
    }
    
    // Return smoothed position with best accuracy from window
    return Position(
      latitude: weightedLat / totalWeight,
      longitude: weightedLng / totalWeight,
      timestamp: newPosition.timestamp,
      accuracy: bestAccuracy,
      altitude: newPosition.altitude,
      altitudeAccuracy: newPosition.altitudeAccuracy,
      heading: newPosition.heading,
      headingAccuracy: newPosition.headingAccuracy,
      speed: newPosition.speed,
      speedAccuracy: newPosition.speedAccuracy,
    );
  }
  
  /// Process GPS position update with accuracy filtering and smoothing
  Future<void> _processGpsPosition(Position position) async {
    if (_currentUserId == null) return;
    
    // Reset bad reading counter on successful position
    _consecutiveBadReadings = 0;
    
    // IMPORTANT: Skip GPS updates if user has manually pinned their location
    if (_isManualPinMode) {
      if (kDebugMode) debugPrint('📍 GPS Update SKIPPED - Manual Pin Mode is active');
      return;
    }
    
    // Filter out inaccurate readings (but still accept if no better option)
    if (position.accuracy > LocationConfig.minAccuracyMeters) {
      if (kDebugMode) debugPrint('📍 Low accuracy reading: ${position.accuracy}m (threshold: ${LocationConfig.minAccuracyMeters}m)');
      // If we have a recent good location, skip this bad reading
      if (_lastLocation != null && 
          _lastLocation!.accuracy != null &&
          _lastLocation!.accuracy! < position.accuracy) {
        final timeSinceLastUpdate = DateTime.now().difference(_lastLocation!.timestamp);
        if (timeSinceLastUpdate.inSeconds < LocationConfig.staleThresholdSeconds) {
          if (kDebugMode) debugPrint('📍 Skipping low accuracy reading, using cached location');
          return;
        }
      }
    }

    // Only accepted readings are allowed to keep the location fresh.
    _lastGpsTimestamp = DateTime.now();
    
    // Apply smoothing for more stable position
    final smoothedPosition = _smoothPosition(position);
    
    // Check against ALL SKSU campuses
    final withinCampus = isWithinAnyCampus(smoothedPosition.latitude, smoothedPosition.longitude);
    final currentCampusLocation = getCampusForLocation(smoothedPosition.latitude, smoothedPosition.longitude);
    
    // Detect movement with hysteresis to prevent jitter
    bool wasMoving = _isMoving;
    if (_previousPosition != null) {
      final distance = _calculateDistance(_previousPosition!, smoothedPosition);
      // Use different thresholds for starting/stopping movement
      if (_isMoving) {
        _isMoving = distance > LocationConfig.movementThreshold * 0.5; // Lower threshold to keep moving
      } else {
        _isMoving = distance > LocationConfig.movementThreshold; // Higher threshold to start moving
      }
      
      // Movement state change is picked up by _onUnifiedTick on the next tick —
      // the unified timer auto-adapts by reading _isMoving, so no restart needed.
      if (wasMoving != _isMoving) {
        if (kDebugMode) debugPrint('📍 Movement state changed: ${_isMoving ? "MOVING" : "STATIONARY"}');
      }
    }
_previousPosition = smoothedPosition;

    // Guard against stopTracking being called mid-processing
    if (_currentUserId == null) return;

        final location = LocationModel(
      userId: _currentUserId!,
      latitude: smoothedPosition.latitude,
      longitude: smoothedPosition.longitude,
      status: _currentStatus,
      quickMessage: _currentQuickMessage,
      timestamp: DateTime.now(),
      isWithinCampus: withinCampus,
      locationCampusId: currentCampusLocation,
      visibilityScope: _visibilityScope,
      statusExpiresAt: _statusExpiresAt,
      accuracy: smoothedPosition.accuracy,
      isMoving: _isMoving,
      isManualPin: false,
    );
    
    _lastLocation = location;
    
    // Throttle Firestore updates when stationary to reduce writes
    final now = DateTime.now();
    final shouldUpdate = _isMoving || 
        _lastFirestoreUpdate == null ||
        now.difference(_lastFirestoreUpdate!).inSeconds >= LocationConfig.unifiedTickSeconds;
    
    if (shouldUpdate) {
      final written = await updateLocation(_currentUserId!, location);
      if (written) _lastFirestoreUpdate = now;
      if (kDebugMode) debugPrint('📍 Location UPDATED: accuracy=${smoothedPosition.accuracy.toStringAsFixed(1)}m, campus=$currentCampusLocation, moving=$_isMoving');
    }
    
    _onLocationUpdate?.call(location);
  }
  
  /// Update status and message without restarting tracking
  void updateStatusAndMessage(
    String? status,
    String? quickMessage, {
    DateTime? statusExpiresAt,
  }) {
    _currentStatus = status;
    _currentQuickMessage = quickMessage;
    _statusExpiresAt = statusExpiresAt ?? _statusExpiresAt;
  }

  void updateVisibilityScope(LocationVisibilityScope scope) {
    _visibilityScope = scope;
  }
  
  /// Stop location tracking
  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _unifiedTimer?.cancel();
    _unifiedTimer = null;
    _lastLocation = null;
    _currentUserId = null;
    _previousPosition = null;
    _isMoving = false;
    _isManualPinMode = false;
    _onLocationUpdate = null;
    _positionHistory.clear();
    _lastFirestoreUpdate = null;
    _lastGpsTimestamp = null;
    _lastManualPinRefresh = null;
    _consecutiveBadReadings = 0;
  }
   
  /// Switch from manual pin to automatic GPS tracking
  void switchToAutoTracking() {
    _isManualPinMode = false;
    _lastManualPinRefresh = null;
    if (kDebugMode) debugPrint('📍 Switched to automatic GPS tracking');
  }
  
  /// Update location in Firestore. Returns true on success, false on failure
  /// (callers may surface "offline" state or retry).
  Future<bool> updateLocation(String userId, LocationModel location) async {
    final result = Completer<bool>();
    _locationWriteQueue = _locationWriteQueue.then((_) async {
      try {
        result.complete(await _writeLocation(userId, location));
      } catch (e) {
        result.complete(false);
      }
    });
    return result.future;
  }

  Future<bool> _writeLocation(String userId, LocationModel location) async {
    try {
      await _firestore
          .collection('locations')
          .doc(userId)
          .set(location.toFirestore());
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Error updating location: $e');
      return false;
    }
  }
   
  /// Remove location from Firestore (when tracking is disabled or outside campus).
  /// Returns true on success, false on failure (a failed delete leaves a stale
  /// location doc that students may still read — callers can retry).
  Future<bool> removeLocation(String userId) async {
    try {
      await _locationWriteQueue;
      if (kDebugMode) debugPrint('🗑️ Removing location for user: $userId');
      await _firestore.collection('locations').doc(userId).delete();
      if (kDebugMode) debugPrint('🗑️ Location successfully removed from Firestore');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Error removing location: $e');
      return false;
    }
  }
  
  /// Get location by user ID
  Future<LocationModel?> getLocationByUserId(String userId) async {
    try {
      final doc = await _firestore.collection('locations').doc(userId).get();
      if (doc.exists) {
        return LocationModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('Error getting location: $e');
      return null;
    }
  }
  
  /// Stream of all active locations
  Stream<List<LocationModel>> getActiveLocationsStream() {
    return _firestore
        .collection('locations')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LocationModel.fromFirestore(doc))
            .toList());
  }
  
  /// Stream of specific user's location
  Stream<LocationModel?> getLocationStream(String userId) {
    return _firestore
        .collection('locations')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? LocationModel.fromFirestore(doc) : null);
  }
  
  /// Calculate distance between two points
  double calculateDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }
  
  /// Estimate walking time (average walking speed: 5 km/h = 83.33 m/min)
  int estimateWalkingTimeMinutes(double distanceMeters) {
    const walkingSpeedMetersPerMinute = 83.33;
    return (distanceMeters / walkingSpeedMetersPerMinute).ceil();
  }

  // ==================== TEST HELPER METHODS ====================
  // These methods are exposed for unit testing purposes

  /// Check if a position has acceptable accuracy
  @visibleForTesting
  bool isPositionAccurate(Position position) {
    return position.accuracy <= LocationConfig.minAccuracyMeters;
  }

  /// Check if user has moved above the threshold
  @visibleForTesting
  bool hasUserMoved(Position? previous, Position current) {
    if (previous == null) return true;
    final distance = _calculateDistance(previous, current);
    return distance > LocationConfig.movementThreshold;
  }

  /// Calculate smoothed position from position history
  @visibleForTesting
  Position? calculateSmoothedPosition(List<Position> history) {
    if (history.length < LocationConfig.smoothingWindowSize) {
      return null;
    }

    double sumLat = 0;
    double sumLng = 0;
    double sumAccuracy = 0;

    for (final pos in history) {
      sumLat += pos.latitude;
      sumLng += pos.longitude;
      sumAccuracy += pos.accuracy;
    }

    final count = history.length;
    return Position(
      latitude: sumLat / count,
      longitude: sumLng / count,
      timestamp: history.last.timestamp,
      accuracy: sumAccuracy / count,
      altitude: history.last.altitude,
      heading: history.last.heading,
      speed: history.last.speed,
      speedAccuracy: history.last.speedAccuracy,
      altitudeAccuracy: history.last.altitudeAccuracy,
      headingAccuracy: history.last.headingAccuracy,
    );
  }

  /// Get current position history (for testing)
  @visibleForTesting
  List<Position> get positionHistory => List.unmodifiable(_positionHistory);

  /// Clear position history (for testing)
  @visibleForTesting
  void clearPositionHistory() {
    _positionHistory.clear();
  }
  
  /// Dispose
  void dispose() {
    stopTracking();
  }
}
