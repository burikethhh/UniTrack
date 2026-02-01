import 'package:cloud_firestore/cloud_firestore.dart';

/// User roles enum
enum UserRole { student, staff, admin }

/// User model for UniTrack
class UserModel {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final UserRole role;
  final String? department;
  final String? position;
  final String? photoUrl;
  final String? phoneNumber;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  
  // Campus field - determines user's default campus
  final String campusId; // 'isulan', 'tacurong', or 'access'
  
  // Staff-specific fields
  final bool? isTrackingEnabled;
  final String? currentStatus;
  final String? quickMessage;
  final List<String>? officeHours;
  
  UserModel({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.department,
    this.position,
    this.photoUrl,
    this.phoneNumber,
    this.isActive = true,
    required this.createdAt,
    this.lastLoginAt,
    this.campusId = 'isulan', // Default to Isulan campus
    this.isTrackingEnabled,
    this.currentStatus,
    this.quickMessage,
    this.officeHours,
  });
  
  /// Full name getter
  String get fullName => '$firstName $lastName';
  
  /// Initials for avatar
  String get initials {
    String initials = '';
    if (firstName.isNotEmpty) initials += firstName[0].toUpperCase();
    if (lastName.isNotEmpty) initials += lastName[0].toUpperCase();
    return initials;
  }
  
  /// Check if user is staff
  bool get isStaff => role == UserRole.staff || role == UserRole.admin;
  
  /// Check if user is admin
  bool get isAdmin => role == UserRole.admin;
  
  /// Get role as string
  String get roleString {
    switch (role) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.staff:
        return 'Faculty/Staff';
      case UserRole.student:
        return 'Student';
    }
  }
  
  /// Create from Firestore document
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      email: data['email'] ?? '',
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      role: _parseRole(data['role']),
      department: data['department'],
      position: data['position'],
      photoUrl: data['photoUrl'],
      phoneNumber: data['phoneNumber'],
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate(),
      campusId: data['campusId'] ?? 'isulan', // Default to Isulan if not set
      isTrackingEnabled: data['isTrackingEnabled'],
      currentStatus: data['currentStatus'],
      quickMessage: data['quickMessage'],
      officeHours: data['officeHours'] != null 
          ? List<String>.from(data['officeHours']) 
          : null,
    );
  }
  
  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'role': role.name,
      'department': department,
      'position': position,
      'photoUrl': photoUrl,
      'phoneNumber': phoneNumber,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
      'campusId': campusId,
      'isTrackingEnabled': isTrackingEnabled,
      'currentStatus': currentStatus,
      'quickMessage': quickMessage,
      'officeHours': officeHours,
    };
  }
  
  /// Create a copy with updated fields
  UserModel copyWith({
    String? id,
    String? email,
    String? firstName,
    String? lastName,
    UserRole? role,
    String? department,
    String? position,
    String? photoUrl,
    String? phoneNumber,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    String? campusId,
    bool? isTrackingEnabled,
    String? currentStatus,
    String? quickMessage,
    List<String>? officeHours,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      role: role ?? this.role,
      department: department ?? this.department,
      position: position ?? this.position,
      photoUrl: photoUrl ?? this.photoUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      campusId: campusId ?? this.campusId,
      isTrackingEnabled: isTrackingEnabled ?? this.isTrackingEnabled,
      currentStatus: currentStatus ?? this.currentStatus,
      quickMessage: quickMessage ?? this.quickMessage,
      officeHours: officeHours ?? this.officeHours,
    );
  }
  
  /// Parse role from string
  static UserRole _parseRole(String? roleString) {
    switch (roleString?.toLowerCase()) {
      case 'staff':
        return UserRole.staff;
      case 'admin':
        return UserRole.admin;
      case 'student':
      default:
        return UserRole.student;
    }
  }
  
  @override
  String toString() {
    return 'UserModel(id: $id, email: $email, name: $fullName, role: ${role.name})';
  }
}
