import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/location_service.dart';
import '../services/database_service.dart';
import '../core/constants/app_constants.dart';

/// Location Provider for tracking
class LocationProvider extends ChangeNotifier {
  final LocationService _locationService;
  final DatabaseService _databaseService = DatabaseService();

  LocationProvider({required LocationService locationService})
    : _locationService = locationService;

  String? _userId;
  String? _userCampusId; // User's assigned campus
  bool _isTracking = false;
  bool _isBackgroundTrackingEnabled =
      false; // Track if background tracking is on
  LocationModel? _currentLocation;
  String _currentStatus = AvailabilityStatus.available.displayName;
  AvailabilityStatus _availabilityStatus = AvailabilityStatus.available;
  DateTime? _statusUpdatedAt;
  DateTime? _statusExpiresAt;
  LocationVisibilityScope _visibilityScope = LocationVisibilityScope.campusOnly;
  String? _currentMessage;
  bool _hasPermission = false;
  String? _error;
  DateTime? _lastUpdate;
  DateTime? _trackingStartTime;
  Timer? _scheduleTimer; // Periodic timer to enforce auto-hide schedule
  int _sessionGeneration = 0;
  Future<void>? _initializeFuture;

  // Getters
  bool get isTracking => _isTracking;
  bool get isBackgroundTrackingEnabled => _isBackgroundTrackingEnabled;
  LocationModel? get currentLocation => _currentLocation;
  String get currentStatus => _effectiveStatus.displayName;
  AvailabilityStatus get availabilityStatus => _effectiveStatus;
  DateTime? get statusExpiresAt => _statusExpiresAt;
  LocationVisibilityScope get visibilityScope => _visibilityScope;
  String? get userCampusId => _userCampusId;
  String? get currentMessage => _currentMessage;
  bool get hasPermission => _hasPermission;
  String? get error => _error;
  bool get isWithinCampus => _currentLocation?.isWithinCampus ?? false;
  DateTime? get lastUpdate => _lastUpdate;
  bool get isMoving => _currentLocation?.isMoving ?? false;

  AvailabilityStatus get _effectiveStatus {
    if (_statusExpiresAt != null && DateTime.now().isAfter(_statusExpiresAt!)) {
      return AvailabilityStatus.available;
    }
    return _availabilityStatus;
  }

  int get trackingDurationMinutes {
    if (_trackingStartTime == null) return 0;
    return DateTime.now().difference(_trackingStartTime!).inMinutes;
  }

  /// Initialize the provider for a user
  Future<void> initialize(String userId, {String? campusId}) async {
    if (_initializeFuture != null) return _initializeFuture!;
    final future = _initializeInternal(userId, campusId: campusId);
    _initializeFuture = future;
    try {
      await future;
    } finally {
      if (identical(_initializeFuture, future)) _initializeFuture = null;
    }
  }

  Future<void> _initializeInternal(String userId, {String? campusId}) async {
    if (_userId == userId && _scheduleTimer != null) return;
    if (_userId != null && _userId != userId) {
      await stopTracking();
    }
    final generation = ++_sessionGeneration;
    _userId = userId;
    _userCampusId = campusId ?? AppConstants.defaultCampusId;
    await checkPermission();
    await _loadSettingsAndRestoreTracking(generation);
  }

  /// Load settings from SharedPreferences and restore tracking if it was active
  Future<void> _loadSettingsAndRestoreTracking(int generation) async {
    final prefs = await SharedPreferences.getInstance();
    if (generation != _sessionGeneration) return;
    _currentStatus =
        prefs.getString('currentStatus_$_userId') ??
        AvailabilityStatus.available.displayName;
    _availabilityStatus =
        AvailabilityStatusExtension.fromString(_currentStatus) ??
        AvailabilityStatus.available;
    _statusUpdatedAt = DateTime.tryParse(
      prefs.getString('statusUpdatedAt_$_userId') ?? '',
    );
    _statusExpiresAt = DateTime.tryParse(
      prefs.getString('statusExpiresAt_$_userId') ?? '',
    );
    _currentMessage = prefs.getString('currentMessage_$_userId');
    _visibilityScope =
        prefs.getString('visibilityScope_$_userId') == 'universityWide'
        ? LocationVisibilityScope.universityWide
        : LocationVisibilityScope.campusOnly;

    // Check if tracking was previously active for this user
    final wasTracking = prefs.getBool('isTracking_$_userId') ?? false;
    _isBackgroundTrackingEnabled =
        prefs.getBool('backgroundTracking_$_userId') ?? false;

    notifyListeners();

    // Auto-restore tracking if it was active before app closed (including background tracking)
    // but respect the auto-hide schedule
    if (wasTracking && _userId != null && generation == _sessionGeneration) {
      if (await _isInAutoHideWindow()) {
        if (kDebugMode) {
          debugPrint(
            '📍 Skipping tracking restore — auto-hide schedule is active',
          );
        }
        await stopTracking();
      } else {
        await startTracking();
        if (kDebugMode) {
          debugPrint(
            '📍 Restored tracking for user (background=$_isBackgroundTrackingEnabled)',
          );
        }
      }
    }

    // Start a periodic timer (every 60s) to enforce the auto-hide schedule
    _scheduleTimer?.cancel();
    _scheduleTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      if (generation != _sessionGeneration) return;
      if (_statusExpiresAt != null &&
          DateTime.now().isAfter(_statusExpiresAt!) &&
          _availabilityStatus != AvailabilityStatus.available) {
        await setStatus(AvailabilityStatus.available.displayName);
      }
      if (!_isTracking) return;
      if (await _isInAutoHideWindow()) {
        if (kDebugMode) {
          debugPrint('📍 Auto-hide schedule triggered — stopping tracking');
        }
        await stopTracking();
      }
    });
  }

  /// Check whether the current time falls inside the auto-hide window
  Future<bool> _isInAutoHideWindow() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('autohide_enabled') ?? false;
    if (!enabled) return false;

    final hideWeekends = prefs.getBool('autohide_weekends') ?? true;
    final now = DateTime.now();

    // Weekend check (Saturday=6, Sunday=7)
    if (hideWeekends &&
        (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday)) {
      return true;
    }

    final startHour = prefs.getInt('autohide_start_hour') ?? 17;
    final startMinute = prefs.getInt('autohide_start_minute') ?? 0;
    final endHour = prefs.getInt('autohide_end_hour') ?? 8;
    final endMinute = prefs.getInt('autohide_end_minute') ?? 0;

    final startMinutes = startHour * 60 + startMinute;
    final endMinutes = endHour * 60 + endMinute;
    final nowMinutes = now.hour * 60 + now.minute;

    // Handle overnight window (e.g. 17:00 → 08:00)
    if (startMinutes > endMinutes) {
      // Hidden if after start OR before end
      return nowMinutes >= startMinutes || nowMinutes < endMinutes;
    } else {
      // Same-day range (e.g. 12:00 → 13:00)
      return nowMinutes >= startMinutes && nowMinutes < endMinutes;
    }
  }

  /// Save tracking state
  Future<void> _saveTrackingState(bool isTracking) async {
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isTracking_$_userId', isTracking);
  }

  /// Save background tracking state
  Future<void> _saveBackgroundTrackingState(bool enabled) async {
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('backgroundTracking_$_userId', enabled);
  }

  /// Save status to preferences
  Future<void> _saveStatus() async {
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currentStatus_$_userId', _currentStatus);
    await prefs.setString(
      'statusUpdatedAt_$_userId',
      (_statusUpdatedAt ?? DateTime.now()).toIso8601String(),
    );
    if (_statusExpiresAt != null) {
      await prefs.setString(
        'statusExpiresAt_$_userId',
        _statusExpiresAt!.toIso8601String(),
      );
    } else {
      await prefs.remove('statusExpiresAt_$_userId');
    }
    if (_currentMessage != null) {
      await prefs.setString('currentMessage_$_userId', _currentMessage!);
    } else {
      await prefs.remove('currentMessage_$_userId');
    }
  }

  Future<void> setVisibilityScope(LocationVisibilityScope scope) async {
    _visibilityScope = scope;
    _locationService.updateVisibilityScope(scope);
    if (_userId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('visibilityScope_$_userId', scope.name);
      if (_isTracking && _currentLocation != null) {
        final updated = _currentLocation!.copyWith(
          visibilityScope: scope,
          timestamp: DateTime.now(),
        );
        _currentLocation = updated;
        await _locationService.updateLocation(_userId!, updated);
      }
    }
    notifyListeners();
  }

  /// Enable native background tracking. Browser sessions remain foreground-only.
  Future<void> enableBackgroundTracking() async {
    if (kIsWeb) {
      _isBackgroundTrackingEnabled = false;
      _error = 'Continuous background tracking is available in the mobile app.';
      notifyListeners();
      return;
    }
    _isBackgroundTrackingEnabled = true;
    await _saveBackgroundTrackingState(true);

    // Ensure tracking is running
    if (!_isTracking && _userId != null) {
      await startTracking();
    }

    if (kDebugMode) debugPrint('📍 Background tracking ENABLED');
    notifyListeners();
  }

  /// Disable background tracking
  Future<void> disableBackgroundTracking() async {
    _isBackgroundTrackingEnabled = false;
    await _saveBackgroundTrackingState(false);

    if (kDebugMode) debugPrint('📍 Background tracking DISABLED');
    notifyListeners();
  }

  /// Check location permission
  Future<bool> checkPermission() async {
    _hasPermission = await _locationService.checkAndRequestPermission();
    notifyListeners();
    return _hasPermission;
  }

  /// Start tracking
  Future<bool> startTracking() async {
    if (_userId == null) return false;
    final userId = _userId!;
    final generation = ++_sessionGeneration;

    if (!_hasPermission) {
      _hasPermission = await _locationService.checkAndRequestPermission();
      if (!_hasPermission) {
        _error = 'Location permission denied';
        notifyListeners();
        return false;
      }
    }

    _isTracking = true;
    _trackingStartTime = DateTime.now();

    // Save tracking state for persistence
    await _saveTrackingState(true);

    notifyListeners();

    // Update database
    await _databaseService.updateTrackingStatus(userId, true);

    // Get current position immediately
    try {
      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        // Check against ALL SKSU campuses (faculty can travel between campuses)
        final withinCampus = _locationService.isWithinAnyCampus(
          position.latitude,
          position.longitude,
        );
        final location = LocationModel(
          userId: userId,
          latitude: position.latitude,
          longitude: position.longitude,
          status: _currentStatus,
          quickMessage: _currentMessage,
          timestamp: DateTime.now(),
          isWithinCampus: withinCampus,
          locationCampusId: _locationService.getCampusForLocation(
            position.latitude,
            position.longitude,
          ),
          visibilityScope: _visibilityScope,
          statusExpiresAt: _statusExpiresAt,
          accuracy: position.accuracy,
          isMoving: false,
          isManualPin: false,
        );

        _currentLocation = location;
        _lastUpdate = DateTime.now();

        // Always save location - isWithinCampus flag determines map visibility
        // This keeps user "online" even when outside campus
        await _locationService.updateLocation(userId, location);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error getting initial position: $e');
    }

    // Start location updates
    _locationService.startTracking(
      userId: userId,
      status: _currentStatus,
      quickMessage: _currentMessage,
      campusId: _userCampusId,
      statusExpiresAt: _statusExpiresAt,
      visibilityScope: _visibilityScope,
      onLocationUpdate: (location) {
        if (generation != _sessionGeneration ||
            _userId != userId ||
            !_isTracking) {
          return;
        }
        _currentLocation = location;
        _lastUpdate = DateTime.now();
        notifyListeners();
      },
    );

    return true;
  }

  /// Stop tracking
  Future<void> stopTracking() async {
    if (_userId == null) return;
    final userId = _userId!;
    ++_sessionGeneration;

    _isTracking = false;
    _isBackgroundTrackingEnabled = false; // Also disable background tracking
    _locationService.stopTracking();

    // Save tracking state for persistence
    await _saveTrackingState(false);
    await _saveBackgroundTrackingState(false);

    // Remove location from database
    await _locationService.removeLocation(userId);
    await _databaseService.updateTrackingStatus(userId, false);

    _currentLocation = null;
    _trackingStartTime = null;
    if (kDebugMode) debugPrint('📍 Tracking STOPPED');
    notifyListeners();
  }

  /// Set status
  Future<void> setStatus(String status, {Duration? duration}) async {
    final parsed =
        AvailabilityStatusExtension.fromString(status) ??
        AvailabilityStatus.available;
    _availabilityStatus = parsed;
    _currentStatus = parsed.displayName;
    _statusUpdatedAt = DateTime.now();
    _statusExpiresAt = _statusExpiryFor(parsed, _statusUpdatedAt!, duration);
    await _saveStatus();

    if (_userId != null) {
      // Update status in user document
      await _databaseService.updateUserStatus(
        _userId!,
        _currentStatus,
        availabilityStatus: parsed,
        statusUpdatedAt: _statusUpdatedAt,
        statusExpiresAt: _statusExpiresAt,
      );

      // Update the location service's stored canonical status.
      _locationService.updateStatusAndMessage(
        _currentStatus,
        _currentMessage,
        statusExpiresAt: _statusExpiresAt,
      );

      // Also update in location document for real-time sync
      if (_currentLocation != null) {
        final updatedLocation = _currentLocation!.copyWith(
          status: _currentStatus,
          timestamp: DateTime.now(),
          statusExpiresAt: _statusExpiresAt,
        );
        _currentLocation = updatedLocation;
        await _locationService.updateLocation(_userId!, updatedLocation);
      }
    }
    notifyListeners();
  }

  DateTime _statusExpiryFor(
    AvailabilityStatus status,
    DateTime from, [
    Duration? duration,
  ]) {
    if (duration != null) return from.add(duration);
    switch (status) {
      case AvailabilityStatus.available:
        final endOfDay = DateTime(from.year, from.month, from.day + 1);
        return endOfDay;
      case AvailabilityStatus.teaching:
        return from.add(const Duration(hours: 4));
      case AvailabilityStatus.onBreak:
        return from.add(const Duration(hours: 1));
      default:
        return from.add(const Duration(hours: 2));
    }
  }

  /// Set quick message
  Future<void> setQuickMessage(String? message) async {
    _currentMessage = message;
    await _saveStatus();

    if (_userId != null) {
      // Update message in user document
      await _databaseService.updateQuickMessage(_userId!, message);

      // Update the location service's stored message
      _locationService.updateStatusAndMessage(
        _currentStatus,
        message,
        statusExpiresAt: _statusExpiresAt,
      );

      // Also update in location document for real-time sync
      if (_currentLocation != null) {
        final updatedLocation = _currentLocation!.copyWith(
          quickMessage: message,
          timestamp: DateTime.now(),
          visibilityScope: _visibilityScope,
        );
        _currentLocation = updatedLocation;
        await _locationService.updateLocation(_userId!, updatedLocation);
      }
    }
    notifyListeners();
  }

  /// Check if currently in manual pin mode
  bool get isManualPinMode => _locationService.isManualPinMode;

  /// Set manual location (for manual pinning on map)
  /// This pins the location and STOPS GPS from overwriting it
  Future<void> setManualLocation(double latitude, double longitude) async {
    if (_userId == null) return;

    // Check against ALL SKSU campuses (faculty can pin location at any campus)
    final withinCampus = _locationService.isWithinAnyCampus(
      latitude,
      longitude,
    );

    final location = LocationModel(
      userId: _userId!,
      latitude: latitude,
      longitude: longitude,
      status: _currentStatus,
      quickMessage: _currentMessage,
      timestamp: DateTime.now(),
      isWithinCampus: withinCampus,
      locationCampusId: _locationService.getCampusForLocation(
        latitude,
        longitude,
      ),
      visibilityScope: _visibilityScope,
      statusExpiresAt: _statusExpiresAt,
      accuracy: 0, // Manual pin has no GPS accuracy
      isMoving: false, // Manual pin is always stationary
      isManualPin: true,
    );

    _currentLocation = location;
    _lastUpdate = DateTime.now();

    // Use the location service's manual pin method - this enables manual pin mode
    // which prevents GPS updates from overwriting this location
    await _locationService.setManualLocation(_userId!, location);
    await _databaseService.updateTrackingStatus(_userId!, true);
    _isTracking = true;

    await _saveTrackingState(_isTracking);

    notifyListeners();
  }

  /// Switch from manual pin back to automatic GPS tracking
  Future<void> switchToAutoTracking() async {
    _locationService.switchToAutoTracking();

    // Get current GPS position and update
    if (_userId != null) {
      try {
        final position = await _locationService.getCurrentPosition();
        if (position != null) {
          final withinCampus = _locationService.isWithinAnyCampus(
            position.latitude,
            position.longitude,
          );
          final location = LocationModel(
            userId: _userId!,
            latitude: position.latitude,
            longitude: position.longitude,
            status: _currentStatus,
            quickMessage: _currentMessage,
            timestamp: DateTime.now(),
            isWithinCampus: withinCampus,
            locationCampusId: _locationService.getCampusForLocation(
              position.latitude,
              position.longitude,
            ),
            visibilityScope: _visibilityScope,
            statusExpiresAt: _statusExpiresAt,
            accuracy: position.accuracy,
            isMoving: false,
            isManualPin: false,
          );

          _currentLocation = location;
          _lastUpdate = DateTime.now();
          await _locationService.updateLocation(_userId!, location);
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Error switching to auto tracking: $e');
      }
    }

    notifyListeners();
  }

  /// Get current position once
  Future<Position?> getCurrentPosition() async {
    return await _locationService.getCurrentPosition();
  }

  /// Calculate distance to target
  double? getDistanceTo(double targetLat, double targetLng) {
    if (_currentLocation == null) return null;
    return _locationService.calculateDistance(
      _currentLocation!.latitude,
      _currentLocation!.longitude,
      targetLat,
      targetLng,
    );
  }

  /// Estimate walking time to target
  int? getWalkingTimeTo(double targetLat, double targetLng) {
    final distance = getDistanceTo(targetLat, targetLng);
    if (distance == null) return null;
    return _locationService.estimateWalkingTimeMinutes(distance);
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Dispose
  @override
  void dispose() {
    _scheduleTimer?.cancel();
    _locationService.dispose();
    super.dispose();
  }
}
