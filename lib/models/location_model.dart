import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

/// Location model for real-time tracking
class LocationModel {
  final String userId;
  final double latitude;
  final double longitude;
  final String? status;
  final String? quickMessage;
  final DateTime timestamp;
  final bool isWithinCampus;
  final double? accuracy;
  final bool isMoving; // True if teacher is moving (GPS mode only)
  final bool isManualPin; // True if location was set manually
  
  LocationModel({
    required this.userId,
    required this.latitude,
    required this.longitude,
    this.status,
    this.quickMessage,
    required this.timestamp,
    this.isWithinCampus = true,
    this.accuracy,
    this.isMoving = false,
    this.isManualPin = false,
  });
  
  /// Get as LatLng for map
  LatLng get latLng => LatLng(latitude, longitude);
  
  /// Create from Firestore document
  factory LocationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LocationModel(
      userId: doc.id,
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      status: data['status'],
      quickMessage: data['quickMessage'],
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isWithinCampus: data['isWithinCampus'] ?? true,
      accuracy: (data['accuracy'] as num?)?.toDouble(),
      isMoving: data['isMoving'] ?? false,
      isManualPin: data['isManualPin'] ?? false,
    );
  }
  
  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'status': status,
      'quickMessage': quickMessage,
      'timestamp': Timestamp.fromDate(timestamp),
      'isWithinCampus': isWithinCampus,
      'accuracy': accuracy,
      'isMoving': isMoving,
      'isManualPin': isManualPin,
    };
  }
  
  /// Create a copy with updated fields
  LocationModel copyWith({
    String? userId,
    double? latitude,
    double? longitude,
    String? status,
    String? quickMessage,
    DateTime? timestamp,
    bool? isWithinCampus,
    double? accuracy,
    bool? isMoving,
    bool? isManualPin,
  }) {
    return LocationModel(
      userId: userId ?? this.userId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      status: status ?? this.status,
      quickMessage: quickMessage ?? this.quickMessage,
      timestamp: timestamp ?? this.timestamp,
      isWithinCampus: isWithinCampus ?? this.isWithinCampus,
      accuracy: accuracy ?? this.accuracy,
      isMoving: isMoving ?? this.isMoving,
      isManualPin: isManualPin ?? this.isManualPin,
    );
  }
  
  @override
  String toString() {
    return 'LocationModel(userId: $userId, lat: $latitude, lng: $longitude, status: $status)';
  }
}
