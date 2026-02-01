import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/location_service.dart';
import '../services/database_service.dart';

/// Location Provider for staff tracking
class LocationProvider extends ChangeNotifier {
  final LocationService _locationService;
  final DatabaseService _databaseService = DatabaseService();
  
  LocationProvider({
    required LocationService locationService,
  }) : _locationService = locationService;
  
  String? _userId;
  String? _userCampusId; // User's assigned campus
  bool _isTracking = false;
  bool _isBackgroundTrackingEnabled = false; // Track if background tracking is on
  LocationModel? _currentLocation;
  String _currentStatus = 'Available';
  String? _currentMessage;
  bool _hasPermission = false;
  String? _error;
  DateTime? _lastUpdate;
  DateTime? _trackingStartTime;
  
  // Getters
  bool get isTracking => _isTracking;
  bool get isBackgroundTrackingEnabled => _isBackgroundTrackingEnabled;
  LocationModel? get currentLocation => _currentLocation;
  String get currentStatus => _currentStatus;
  String? get userCampusId => _userCampusId;
  String? get currentMessage => _currentMessage;
  bool get hasPermission => _hasPermission;
  String? get error => _error;
  bool get isWithinCampus => _currentLocation?.isWithinCampus ?? false;
  DateTime? get lastUpdate => _lastUpdate;
  bool get isMoving => _currentLocation?.isMoving ?? false;
  
  int get trackingDurationMinutes {
    if (_trackingStartTime == null) return 0;
    return DateTime.now().difference(_trackingStartTime!).inMinutes;
  }
  
  /// Initialize the provider for a user
  void initialize(String userId, {String? campusId}) {
    _userId = userId;
    _userCampusId = campusId ?? 'isulan'; // Default to Isulan if not specified
    checkPermission();
    _loadSettingsAndRestoreTracking();
  }
  
  /// Load settings from SharedPreferences and restore tracking if it was active
  Future<void> _loadSettingsAndRestoreTracking() async {
    final prefs = await SharedPreferences.getInstance();
    _currentStatus = prefs.getString('currentStatus') ?? 'Available';
    _currentMessage = prefs.getString('currentMessage');
    
    // Check if tracking was previously active for this user
    final wasTracking = prefs.getBool('isTracking_$_userId') ?? false;
    _isBackgroundTrackingEnabled = prefs.getBool('backgroundTracking_$_userId') ?? false;
    
    notifyListeners();
    
    // Auto-restore tracking if it was active before app closed (including background tracking)
    if (wasTracking && _userId != null) {
      await startTracking();
      print('📍 Restored tracking for user (background=${_isBackgroundTrackingEnabled})');
    }
    // No need to clean up existing locations - they are valid if fresh
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currentStatus', _currentStatus);
    if (_currentMessage != null) {
      await prefs.setString('currentMessage', _currentMessage!);
    } else {
      await prefs.remove('currentMessage');
    }
  }
  
  /// Enable background tracking - location continues even when app is closed
  Future<void> enableBackgroundTracking() async {
    _isBackgroundTrackingEnabled = true;
    await _saveBackgroundTrackingState(true);
    
    // Ensure tracking is running
    if (!_isTracking && _userId != null) {
      await startTracking();
    }
    
    print('📍 Background tracking ENABLED');
    notifyListeners();
  }
  
  /// Disable background tracking
  Future<void> disableBackgroundTracking() async {
    _isBackgroundTrackingEnabled = false;
    await _saveBackgroundTrackingState(false);
    
    print('📍 Background tracking DISABLED');
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
    await _databaseService.updateTrackingStatus(_userId!, true);
    
    // Get current position immediately
    try {
      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        // Check against ALL SKSU campuses (staff can travel between campuses)
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
          accuracy: position.accuracy,
          isMoving: false,
          isManualPin: false,
        );
        
        _currentLocation = location;
        _lastUpdate = DateTime.now();
        
        // Always save location - isWithinCampus flag determines map visibility
        // This keeps user "online" even when outside campus
        await _locationService.updateLocation(_userId!, location);
      }
    } catch (e) {
      print('Error getting initial position: $e');
    }
    
    // Start location updates
    _locationService.startTracking(
      userId: _userId!,
      status: _currentStatus,
      quickMessage: _currentMessage,
      campusId: _userCampusId,
      onLocationUpdate: (location) {
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
    
    _isTracking = false;
    _isBackgroundTrackingEnabled = false; // Also disable background tracking
    _locationService.stopTracking();
    
    // Save tracking state for persistence
    await _saveTrackingState(false);
    await _saveBackgroundTrackingState(false);
    
    // Remove location from database
    await _locationService.removeLocation(_userId!);
    await _databaseService.updateTrackingStatus(_userId!, false);
    
    _currentLocation = null;
    _trackingStartTime = null;
    print('📍 Tracking STOPPED');
    notifyListeners();
  }
  
  /// Set status
  Future<void> setStatus(String status) async {
    _currentStatus = status;
    await _saveStatus();
    
    if (_userId != null && _isTracking) {
      // Update status in user document
      await _databaseService.updateUserStatus(_userId!, status);
      
      // Update the location service's stored status
      _locationService.updateStatusAndMessage(status, _currentMessage);
      
      // Also update in location document for real-time sync
      if (_currentLocation != null && _currentLocation!.isWithinCampus) {
        final updatedLocation = _currentLocation!.copyWith(
          status: status,
          timestamp: DateTime.now(),
        );
        _currentLocation = updatedLocation;
        await _locationService.updateLocation(_userId!, updatedLocation);
      }
    }
    notifyListeners();
  }
  
  /// Set quick message
  Future<void> setQuickMessage(String? message) async {
    _currentMessage = message;
    await _saveStatus();
    
    if (_userId != null && _isTracking) {
      // Update message in user document
      await _databaseService.updateQuickMessage(_userId!, message);
      
      // Update the location service's stored message
      _locationService.updateStatusAndMessage(_currentStatus, message);
      
      // Also update in location document for real-time sync
      if (_currentLocation != null && _currentLocation!.isWithinCampus) {
        final updatedLocation = _currentLocation!.copyWith(
          quickMessage: message,
          timestamp: DateTime.now(),
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
    
    // Check against ALL SKSU campuses (staff can pin location at any campus)
    final withinCampus = _locationService.isWithinAnyCampus(latitude, longitude);
    
    final location = LocationModel(
      userId: _userId!,
      latitude: latitude,
      longitude: longitude,
      status: _currentStatus,
      quickMessage: _currentMessage,
      timestamp: DateTime.now(),
      isWithinCampus: withinCampus,
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
            accuracy: position.accuracy,
            isMoving: false,
            isManualPin: false,
          );
          
          _currentLocation = location;
          _lastUpdate = DateTime.now();
          await _locationService.updateLocation(_userId!, location);
        }
      } catch (e) {
        print('Error switching to auto tracking: $e');
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
    _locationService.dispose();
    super.dispose();
  }
}
