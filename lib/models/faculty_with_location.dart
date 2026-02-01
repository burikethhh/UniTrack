import 'user_model.dart';
import 'location_model.dart';
import '../core/constants/app_constants.dart';

/// Combined model for faculty with their location
class FacultyWithLocation {
  final UserModel user;
  final LocationModel? location;
  
  /// Staleness threshold - location older than this is considered offline
  /// Using shorter threshold for more responsive real-time tracking
  static Duration get stalenessThreshold => 
      Duration(seconds: AppConstants.locationStaleThresholdSeconds);
  
  FacultyWithLocation({
    required this.user,
    this.location,
  });
  
  /// Check if location is stale (too old)
  bool get isLocationStale {
    if (location == null) return true;
    final age = DateTime.now().difference(location!.timestamp);
    return age > stalenessThreshold;
  }
  
  /// Check if faculty is currently online/trackable
  /// Staff is online if:
  /// 1. Tracking is enabled in user settings
  /// 2. Location document exists
  /// 3. Location is not stale (updated recently)
  /// 4. Location is within campus boundaries
  bool get isOnline => 
      user.isTrackingEnabled == true && 
      location != null &&
      !isLocationStale &&
      location!.isWithinCampus;
  
  /// Get display status
  String get displayStatus {
    if (!isOnline) return 'Offline';
    return location?.status ?? user.currentStatus ?? 'Available';
  }
  
  /// Check if staff is within campus
  bool get isWithinCampus => location?.isWithinCampus ?? false;
  
  /// Check if location is fresh (very recent update)
  bool get isFreshLocation {
    if (location == null) return false;
    final age = DateTime.now().difference(location!.timestamp);
    return age.inSeconds < 10;
  }
  
  /// Get location accuracy in meters
  double? get locationAccuracy => location?.accuracy;
  
  /// Check if currently moving
  bool get isMoving => location?.isMoving ?? false;
  
  /// Get time since last update
  String get lastSeenText {
    if (location == null) return 'Not available';
    
    final difference = DateTime.now().difference(location!.timestamp);
    
    if (difference.inSeconds < 10) {
      return 'Live';
    } else if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
