import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'user_model.dart';

/// Sentinel value for clearing nullable fields in copyWith
const Object _sentinel = Object();

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
  final String? locationCampusId;
  final LocationVisibilityScope visibilityScope;
  final DateTime? statusExpiresAt;

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
    this.locationCampusId,
    this.visibilityScope = LocationVisibilityScope.campusOnly,
    this.statusExpiresAt,
  });

  /// Get as LatLng for map
  LatLng get latLng => LatLng(latitude, longitude);

  /// Create from Firestore document
  /// Returns null if the document is missing required fields (latitude/longitude)
  static LocationModel? tryFromFirestore(DocumentSnapshot doc) {
    try {
      return LocationModel.fromFirestore(doc);
    } catch (e) {
      return null;
    }
  }

  /// Create from Firestore document
  factory LocationModel.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    if (raw == null) {
      throw StateError(
        'LocationModel.fromFirestore: document ${doc.id} has null data',
      );
    }
    final data = raw as Map<String, dynamic>;
    final lat = data['latitude'];
    final lng = data['longitude'];
    if (lat == null || lng == null) {
      throw StateError(
        'LocationModel.fromFirestore: document ${doc.id} missing lat/lng',
      );
    }
    return LocationModel(
      userId: doc.id,
      latitude: (lat as num).toDouble(),
      longitude: (lng as num).toDouble(),
      status: data['status'],
      quickMessage: data['quickMessage'],
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isWithinCampus: data['isWithinCampus'] ?? true,
      accuracy: (data['accuracy'] as num?)?.toDouble(),
      isMoving: data['isMoving'] ?? false,
      isManualPin: data['isManualPin'] ?? false,
      locationCampusId: data['locationCampusId'] is String
          ? data['locationCampusId'] as String
          : null,
      visibilityScope: data['visibilityScope'] == 'universityWide'
          ? LocationVisibilityScope.universityWide
          : LocationVisibilityScope.campusOnly,
      statusExpiresAt: (data['statusExpiresAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    final data = <String, dynamic>{
      'userId': userId,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': Timestamp.fromDate(timestamp),
      'isWithinCampus': isWithinCampus,
      'isMoving': isMoving,
      'isManualPin': isManualPin,
      'visibilityScope': visibilityScope.name,
    };
    if (status != null) data['status'] = status;
    if (quickMessage != null) data['quickMessage'] = quickMessage;
    if (accuracy != null) data['accuracy'] = accuracy;
    if (locationCampusId != null) data['locationCampusId'] = locationCampusId;
    if (statusExpiresAt != null) {
      data['statusExpiresAt'] = Timestamp.fromDate(statusExpiresAt!);
    }
    return data;
  }

  /// Create a copy with updated fields
  /// Use explicit null to clear nullable fields (status, quickMessage, accuracy)
  LocationModel copyWith({
    String? userId,
    double? latitude,
    double? longitude,
    Object? status = _sentinel,
    Object? quickMessage = _sentinel,
    DateTime? timestamp,
    bool? isWithinCampus,
    Object? accuracy = _sentinel,
    bool? isMoving,
    bool? isManualPin,
    String? locationCampusId,
    LocationVisibilityScope? visibilityScope,
    Object? statusExpiresAt = _sentinel,
  }) {
    return LocationModel(
      userId: userId ?? this.userId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      status: status == _sentinel ? this.status : status as String?,
      quickMessage: quickMessage == _sentinel
          ? this.quickMessage
          : quickMessage as String?,
      timestamp: timestamp ?? this.timestamp,
      isWithinCampus: isWithinCampus ?? this.isWithinCampus,
      accuracy: accuracy == _sentinel ? this.accuracy : accuracy as double?,
      isMoving: isMoving ?? this.isMoving,
      isManualPin: isManualPin ?? this.isManualPin,
      locationCampusId: locationCampusId ?? this.locationCampusId,
      visibilityScope: visibilityScope ?? this.visibilityScope,
      statusExpiresAt: statusExpiresAt == _sentinel
          ? this.statusExpiresAt
          : statusExpiresAt as DateTime?,
    );
  }

  @override
  String toString() {
    return 'LocationModel(userId: $userId, lat: $latitude, lng: $longitude, status: $status)';
  }
}
