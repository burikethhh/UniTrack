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

  FacultyWithLocation({required this.user, this.location});

  /// Check if location is stale (too old)
  bool get isLocationStale {
    if (location == null) return true;
    final age = DateTime.now().difference(location!.timestamp);
    return age > stalenessThreshold;
  }

  /// Check if faculty is currently online/trackable
  /// Staff is online if:
  /// 1. Tracking is NOT explicitly disabled (null = enabled)
  /// 2. Location document exists
  /// 3. Location is not stale (updated recently)
  /// 4. Staff is within campus boundaries
  /// Note: isTrackingEnabled is bool? — treat null as enabled so
  /// pre-existing users or those whose field hasn't been written
  /// yet are still visible when they have a live location.
  bool get isOnline =>
      user.isTrackingEnabled != false &&
      location != null &&
      !isLocationStale &&
      isWithinCampus;

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

  /// Check if location is in a reconnecting state (age 60s–180s).
  /// UI can show a yellow "last seen Xm ago" instead of a confident green dot.
  bool get isReconnecting {
    if (location == null) return false;
    final age = DateTime.now().difference(location!.timestamp);
    return age.inSeconds > 60 && age < stalenessThreshold;
  }

  /// Check if the latest reading has low accuracy (>30m).
  /// UI can show an approximate-position indicator.
  bool get isLowAccuracy => (location?.accuracy ?? 0) > 30;

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
