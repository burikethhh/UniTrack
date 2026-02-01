import 'package:cloud_firestore/cloud_firestore.dart';

/// Department model
class DepartmentModel {
  final String id;
  final String name;
  final String? shortName;
  final String? description;
  final String? headId;
  final String? buildingLocation;
  final int staffCount;
  final bool isActive;
  
  DepartmentModel({
    required this.id,
    required this.name,
    this.shortName,
    this.description,
    this.headId,
    this.buildingLocation,
    this.staffCount = 0,
    this.isActive = true,
  });
  
  /// Create from Firestore document
  factory DepartmentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DepartmentModel(
      id: doc.id,
      name: data['name'] ?? '',
      shortName: data['shortName'],
      description: data['description'],
      headId: data['headId'],
      buildingLocation: data['buildingLocation'],
      staffCount: data['staffCount'] ?? 0,
      isActive: data['isActive'] ?? true,
    );
  }
  
  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'shortName': shortName,
      'description': description,
      'headId': headId,
      'buildingLocation': buildingLocation,
      'staffCount': staffCount,
      'isActive': isActive,
    };
  }
  
  @override
  String toString() {
    return 'DepartmentModel(id: $id, name: $name)';
  }
}
