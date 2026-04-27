import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

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
    );
  }

  @override
  String toString() {
    return 'LocationModel(userId: $userId, lat: $latitude, lng: $longitude, status: $status)';
  }
}
