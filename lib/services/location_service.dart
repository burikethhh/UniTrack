import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import '../models/location_model.dart';
import '../core/constants/app_constants.dart';

/// Location tracking configuration for better accuracy
class LocationConfig {
  /// Minimum accuracy in meters to accept a GPS reading
  static const double minAccuracyMeters = 50.0;
  
  /// Distance filter for GPS stream (meters)
  static const double distanceFilterMeters = 1.0;
  
  /// Movement detection threshold (meters)
  static const double movementThreshold = 0.5;
  
  /// Stale location threshold (seconds)
  static const int staleThresholdSeconds = 30;
  
  /// Location update interval when moving (seconds)
  static const int movingUpdateIntervalSec = 2;
  
  /// Location update interval when stationary (seconds)
  static const int stationaryUpdateIntervalSec = 5;
  
  /// Heartbeat interval to keep location fresh (seconds)
  static const int heartbeatIntervalSec = 10;
  
  /// Number of readings to average for smoothing
  static const int smoothingWindowSize = 3;
}

/// Location Service for UniTrack
class LocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _heartbeatTimer;
  Timer? _movementTimer; // Timer for movement updates
  LocationModel? _lastLocation;
  Position? _previousPosition; // For movement detection
  String? _currentUserId;
  bool _isMoving = false;
  bool _isManualPinMode = false; // Track if user is in manual pin mode
  Function(LocationModel)? _onLocationUpdate;
  String? _currentStatus;
  String? _currentQuickMessage;
  
  // Position history for smoothing (Kalman-like filtering)
  final List<Position> _positionHistory = [];
  DateTime? _lastFirestoreUpdate;
  int _consecutiveBadReadings = 0;
  static const int _maxBadReadings = 5;
  
  /// Force request location permission - will open settings if denied
  Future<bool> checkAndRequestPermission() async {
    // First check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Try to open location settings
      await Geolocator.openLocationSettings();
      // Check again after user returns
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;
    }
    
    // Request location permission using permission_handler for better control
    var status = await ph.Permission.locationWhenInUse.status;
    
    if (status.isDenied) {
      status = await ph.Permission.locationWhenInUse.request();
    }
    
    // If still denied or permanently denied, open app settings
    if (status.isDenied || status.isPermanentlyDenied) {
      await ph.openAppSettings();
      // Check again after user returns
      status = await ph.Permission.locationWhenInUse.status;
    }
    
    if (!status.isGranted) return false;
    
    // Also try to get background location for continuous tracking
    var bgStatus = await ph.Permission.locationAlways.status;
    if (bgStatus.isDenied) {
      await ph.Permission.locationAlways.request();
    }
    
    return true;
  }
  
  /// Get current position
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await checkAndRequestPermission();
      if (!hasPermission) return null;
      
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      );
    } catch (e) {
      print('Error getting position: $e');
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
    print('📍 Campus check (${campusId ?? 'default'}): ($latitude, $longitude) -> inside=$isInside');
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
  
  /// Check if currently in manual pin mode
  bool get isManualPinMode => _isManualPinMode;
  
  /// Set manual pin mode - when true, GPS updates won't overwrite the manual location
  void setManualPinMode(bool enabled) {
    _isManualPinMode = enabled;
    print('📍 Manual Pin Mode: ${enabled ? "ENABLED" : "DISABLED"}');
  }
  
  /// Set manual location (bypasses GPS tracking)
  Future<void> setManualLocation(String userId, LocationModel location) async {
    _isManualPinMode = true;
    _lastLocation = location;
    _currentUserId = userId;
    await updateLocation(userId, location);
    _onLocationUpdate?.call(location);
    print('📍 Manual pin set at (${location.latitude}, ${location.longitude}) - GPS updates paused');
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
  
  /// Start location tracking for staff (GPS mode with movement detection)
  void startTracking({
    required String userId,
    required String? status,
    required String? quickMessage,
    String? campusId, // User's assigned campus for geofence checking
    required Function(LocationModel) onLocationUpdate,
  }) {
    _positionSubscription?.cancel();
    _heartbeatTimer?.cancel();
    _movementTimer?.cancel();
    _currentUserId = userId;
    _currentStatus = status;
    _currentQuickMessage = quickMessage;
    _onLocationUpdate = onLocationUpdate;
    _previousPosition = null;
    _isMoving = false;
    
    // GPS stream for position updates with optimized settings
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation, // Best possible accuracy
        distanceFilter: LocationConfig.distanceFilterMeters.toInt(),
        intervalDuration: Duration(seconds: LocationConfig.movingUpdateIntervalSec),
        forceLocationManager: false, // Use fused location provider
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'UniTrack Location Sharing',
          notificationText: 'Sharing your location with students',
          enableWakeLock: true,
        ),
      ),
    ).listen((Position position) async {
      await _processGpsPosition(position);
    }, onError: (e) {
      print('📍 GPS Stream Error: $e');
    });
    
    // Start adaptive movement detection timer
    _startAdaptiveTimer();
    
    // Heartbeat timer to keep location fresh
    _heartbeatTimer = Timer.periodic(
      Duration(seconds: LocationConfig.heartbeatIntervalSec), 
      (timer) async {
        if (_lastLocation != null && _currentUserId != null) {
          final refreshedLocation = _lastLocation!.copyWith(
            timestamp: DateTime.now(),
          );
          _lastLocation = refreshedLocation;
          await updateLocation(_currentUserId!, refreshedLocation);
          print('📍 Heartbeat: Location refreshed (withinCampus=${_lastLocation!.isWithinCampus})');
        }
      },
    );
  }
  
  /// Start adaptive timer that adjusts based on movement state
  void _startAdaptiveTimer() {
    _movementTimer?.cancel();
    
    final interval = _isMoving 
        ? LocationConfig.movingUpdateIntervalSec 
        : LocationConfig.stationaryUpdateIntervalSec;
    
    _movementTimer = Timer.periodic(Duration(seconds: interval), (timer) async {
      if (_currentUserId == null) return;
      
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            timeLimit: Duration(seconds: 10),
          ),
        );
        await _processGpsPosition(position);
      } catch (e) {
        _consecutiveBadReadings++;
        print('📍 Position request failed: $e (bad readings: $_consecutiveBadReadings)');
        
        // If too many failures, try to refresh with last known position
        if (_consecutiveBadReadings >= _maxBadReadings && _lastLocation != null) {
          final refreshed = _lastLocation!.copyWith(timestamp: DateTime.now());
          await updateLocation(_currentUserId!, refreshed);
          _consecutiveBadReadings = 0;
        }
      }
    });
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
      print('📍 GPS Update SKIPPED - Manual Pin Mode is active');
      return;
    }
    
    // Filter out inaccurate readings (but still accept if no better option)
    if (position.accuracy > LocationConfig.minAccuracyMeters) {
      print('📍 Low accuracy reading: ${position.accuracy}m (threshold: ${LocationConfig.minAccuracyMeters}m)');
      // If we have a recent good location, skip this bad reading
      if (_lastLocation != null && 
          _lastLocation!.accuracy != null &&
          _lastLocation!.accuracy! < position.accuracy) {
        final timeSinceLastUpdate = DateTime.now().difference(_lastLocation!.timestamp);
        if (timeSinceLastUpdate.inSeconds < LocationConfig.staleThresholdSeconds) {
          print('📍 Skipping low accuracy reading, using cached location');
          return;
        }
      }
    }
    
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
      
      // Restart adaptive timer if movement state changed
      if (wasMoving != _isMoving) {
        print('📍 Movement state changed: ${_isMoving ? "MOVING" : "STATIONARY"}');
        _startAdaptiveTimer();
      }
    }
    _previousPosition = smoothedPosition;
    
    final location = LocationModel(
      userId: _currentUserId!,
      latitude: smoothedPosition.latitude,
      longitude: smoothedPosition.longitude,
      status: _currentStatus,
      quickMessage: _currentQuickMessage,
      timestamp: DateTime.now(),
      isWithinCampus: withinCampus,
      accuracy: smoothedPosition.accuracy,
      isMoving: _isMoving,
      isManualPin: false,
    );
    
    _lastLocation = location;
    
    // Throttle Firestore updates when stationary to reduce writes
    final now = DateTime.now();
    final shouldUpdate = _isMoving || 
        _lastFirestoreUpdate == null ||
        now.difference(_lastFirestoreUpdate!).inSeconds >= LocationConfig.stationaryUpdateIntervalSec;
    
    if (shouldUpdate) {
      await updateLocation(_currentUserId!, location);
      _lastFirestoreUpdate = now;
      print('📍 Location UPDATED: accuracy=${smoothedPosition.accuracy.toStringAsFixed(1)}m, campus=$currentCampusLocation, moving=$_isMoving');
    }
    
    _onLocationUpdate?.call(location);
  }
  
  /// Update status and message without restarting tracking
  void updateStatusAndMessage(String? status, String? quickMessage) {
    _currentStatus = status;
    _currentQuickMessage = quickMessage;
  }
  
  /// Stop location tracking
  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _movementTimer?.cancel();
    _movementTimer = null;
    _lastLocation = null;
    _currentUserId = null;
    _previousPosition = null;
    _isMoving = false;
    _isManualPinMode = false;
    _onLocationUpdate = null;
    _positionHistory.clear();
    _lastFirestoreUpdate = null;
    _consecutiveBadReadings = 0;
  }
  
  /// Switch from manual pin to automatic GPS tracking
  void switchToAutoTracking() {
    _isManualPinMode = false;
    print('📍 Switched to automatic GPS tracking');
  }
  
  /// Legacy method - no longer needed but kept for compatibility
  void updateHideOutsideCampusSetting(bool value) {
    // No-op: Auto-hide is now always enabled
  }
  
  /// Update location in Firestore
  Future<void> updateLocation(String userId, LocationModel location) async {
    try {
      await _firestore
          .collection('locations')
          .doc(userId)
          .set(location.toFirestore());
    } catch (e) {
      print('Error updating location: $e');
    }
  }
  
  /// Remove location from Firestore (when tracking is disabled or outside campus)
  Future<void> removeLocation(String userId) async {
    try {
      print('🗑️ Removing location for user: $userId');
      await _firestore.collection('locations').doc(userId).delete();
      print('🗑️ Location successfully removed from Firestore');
    } catch (e) {
      print('Error removing location: $e');
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
      print('Error getting location: $e');
      return null;
    }
  }
  
  /// Stream of all active locations
  Stream<List<LocationModel>> getActiveLocationsStream() {
    return _firestore
        .collection('locations')
        .where('isWithinCampus', isEqualTo: true)
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
  
  /// Dispose
  void dispose() {
    stopTracking();
  }
}
