import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';

/// Campus enum for identifying different SKSU campuses
enum CampusId {
  isulan,
  tacurong,
  access,
  bagumbayan,
  palimbang,
  kalamansig,
  lutayan,
}

/// Campus model containing campus information and geofence data
class CampusModel {
  final String id;
  final String name;
  final String shortName;
  final String location;
  final double centerLat;
  final double centerLng;
  final double radiusMeters;
  final List<List<double>> boundaryPoints;
  final bool isActive;

  const CampusModel({
    required this.id,
    required this.name,
    required this.shortName,
    required this.location,
    required this.centerLat,
    required this.centerLng,
    required this.radiusMeters,
    required this.boundaryPoints,
    this.isActive = true,
  });

  /// Get LatLng center
  List<double> get center => [centerLat, centerLng];

  /// Check if a point is within campus boundary (simple radius check)
  bool isWithinCampus(double lat, double lng) {
    // Convert degree deltas to meters
    final double dxMeters = (lat - centerLat) * 111320;
    final double dyMeters =
        (lng - centerLng) * 111320 * math.cos(centerLat * math.pi / 180);
    final double distanceMeters = math.sqrt(
      dxMeters * dxMeters + dyMeters * dyMeters,
    );
    return distanceMeters <= radiusMeters;
  }

  /// Create from Firestore document
  factory CampusModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CampusModel(
      id: doc.id,
      name: data['name'] ?? '',
      shortName: data['shortName'] ?? '',
      location: data['location'] ?? '',
      centerLat: (data['centerLat'] ?? 0.0).toDouble(),
      centerLng: (data['centerLng'] ?? 0.0).toDouble(),
      radiusMeters: (data['radiusMeters'] ?? 300.0).toDouble(),
      boundaryPoints: data['boundaryPoints'] != null
          ? (data['boundaryPoints'] as List)
                .map(
                  (p) => (p as List).map((v) => (v as num).toDouble()).toList(),
                )
                .toList()
          : [],
      isActive: data['isActive'] ?? true,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'shortName': shortName,
      'location': location,
      'centerLat': centerLat,
      'centerLng': centerLng,
      'radiusMeters': radiusMeters,
      'boundaryPoints': boundaryPoints,
      'isActive': isActive,
    };
  }

  /// Get campus display name
  String get displayName => '$shortName - $name';

  @override
  String toString() => 'CampusModel(id: $id, name: $name)';
}
