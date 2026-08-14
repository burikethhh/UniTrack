import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'notification_model.dart';

/// User notification preferences
class NotificationPreferences {
  final bool pushEnabled;
  final bool inAppEnabled;
  final bool emailEnabled;
  final bool lookingForYou;
  final bool locationUpdates;
  final bool statusChanges;
  final bool systemAlerts;
  final bool appUpdates;
  final bool broadcastMessages;
  final bool adminMessages;
  final bool quietHoursEnabled;
  final String quietHoursStart; // Format: "HH:mm" (24-hour)
  final String quietHoursEnd; // Format: "HH:mm" (24-hour)

  const NotificationPreferences({
    this.pushEnabled = true,
    this.inAppEnabled = true,
    this.emailEnabled = false,
    this.lookingForYou = true,
    this.locationUpdates = true,
    this.statusChanges = true,
    this.systemAlerts = true,
    this.appUpdates = true,
    this.broadcastMessages = true,
    this.adminMessages = true,
    this.quietHoursEnabled = false,
    this.quietHoursStart = '22:00',
    this.quietHoursEnd = '07:00',
  });

  factory NotificationPreferences.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const NotificationPreferences();
    return NotificationPreferences(
      pushEnabled: data['pushEnabled'] is bool
          ? data['pushEnabled'] as bool
          : true,
      inAppEnabled: data['inAppEnabled'] is bool
          ? data['inAppEnabled'] as bool
          : true,
      emailEnabled: data['emailEnabled'] is bool
          ? data['emailEnabled'] as bool
          : false,
      lookingForYou: data['lookingForYou'] is bool
          ? data['lookingForYou'] as bool
          : true,
      locationUpdates: data['locationUpdates'] is bool
          ? data['locationUpdates'] as bool
          : true,
      statusChanges: data['statusChanges'] is bool
          ? data['statusChanges'] as bool
          : true,
      systemAlerts: data['systemAlerts'] is bool
          ? data['systemAlerts'] as bool
          : true,
      appUpdates: data['appUpdates'] is bool
          ? data['appUpdates'] as bool
          : true,
      broadcastMessages: data['broadcastMessages'] is bool
          ? data['broadcastMessages'] as bool
          : true,
      adminMessages: data['adminMessages'] is bool
          ? data['adminMessages'] as bool
          : true,
      quietHoursEnabled: data['quietHoursEnabled'] is bool
          ? data['quietHoursEnabled'] as bool
          : false,
      quietHoursStart: data['quietHoursStart'] is String
          ? data['quietHoursStart'] as String
          : '22:00',
      quietHoursEnd: data['quietHoursEnd'] is String
          ? data['quietHoursEnd'] as String
          : '07:00',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pushEnabled': pushEnabled,
      'inAppEnabled': inAppEnabled,
      'emailEnabled': emailEnabled,
      'lookingForYou': lookingForYou,
      'locationUpdates': locationUpdates,
      'statusChanges': statusChanges,
      'systemAlerts': systemAlerts,
      'appUpdates': appUpdates,
      'broadcastMessages': broadcastMessages,
      'adminMessages': adminMessages,
      'quietHoursEnabled': quietHoursEnabled,
      'quietHoursStart': quietHoursStart,
      'quietHoursEnd': quietHoursEnd,
    };
  }

  NotificationPreferences copyWith({
    bool? pushEnabled,
    bool? inAppEnabled,
    bool? emailEnabled,
    bool? lookingForYou,
    bool? locationUpdates,
    bool? statusChanges,
    bool? systemAlerts,
    bool? appUpdates,
    bool? broadcastMessages,
    bool? adminMessages,
    bool? quietHoursEnabled,
    String? quietHoursStart,
    String? quietHoursEnd,
  }) {
    return NotificationPreferences(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      inAppEnabled: inAppEnabled ?? this.inAppEnabled,
      emailEnabled: emailEnabled ?? this.emailEnabled,
      lookingForYou: lookingForYou ?? this.lookingForYou,
      locationUpdates: locationUpdates ?? this.locationUpdates,
      statusChanges: statusChanges ?? this.statusChanges,
      systemAlerts: systemAlerts ?? this.systemAlerts,
      appUpdates: appUpdates ?? this.appUpdates,
      broadcastMessages: broadcastMessages ?? this.broadcastMessages,
      adminMessages: adminMessages ?? this.adminMessages,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
    );
  }

  bool shouldReceivePush(NotificationType type) {
    if (!pushEnabled) return false;
    if (quietHoursEnabled && _isInQuietHours()) return false;
    switch (type) {
      case NotificationType.lookingForYou:
        return lookingForYou;
      case NotificationType.locationUpdate:
        return locationUpdates;
      case NotificationType.statusChange:
        return statusChanges;
      case NotificationType.system:
        return systemAlerts;
      case NotificationType.appUpdate:
        return appUpdates;
    }
  }

  bool _isInQuietHours() {
    final now = DateTime.now();
    final startParts = quietHoursStart.split(':');
    final endParts = quietHoursEnd.split(':');
    if (startParts.length != 2 || endParts.length != 2) return false;
    final startH = int.tryParse(startParts[0]);
    final startM = int.tryParse(startParts[1]);
    final endH = int.tryParse(endParts[0]);
    final endM = int.tryParse(endParts[1]);
    if (startH == null || startM == null || endH == null || endM == null) {
      return false;
    }
    if (startH < 0 || startH > 23 || endH < 0 || endH > 23) return false;
    if (startM < 0 || startM > 59 || endM < 0 || endM > 59) return false;
    final startMinutes = startH * 60 + startM;
    final endMinutes = endH * 60 + endM;
    final nowMinutes = now.hour * 60 + now.minute;

    if (startMinutes <= endMinutes) {
      return nowMinutes >= startMinutes && nowMinutes < endMinutes;
    } else {
      // Overnight quiet hours (e.g., 22:00 to 07:00)
      return nowMinutes >= startMinutes || nowMinutes < endMinutes;
    }
  }
}

/// User roles enum
enum UserRole { student, organizationOfficer, studentLeader, admin }

/// Faculty availability status enum
enum AvailabilityStatus {
  available,
  busy,
  inMeeting,
  teaching,
  onBreak,
  outOfOffice,
  doNotDisturb,
}

/// Visibility scope for a staff member's live location.
enum LocationVisibilityScope { campusOnly, universityWide }

/// Extension for availability status display properties
extension AvailabilityStatusExtension on AvailabilityStatus {
  static AvailabilityStatus? fromString(String? value) {
    if (value == null) return null;
    final normalized = value.trim().toLowerCase().replaceAll(
      RegExp(r'[ _-]'),
      '',
    );
    switch (normalized) {
      case 'available':
      case 'availableforconsultation':
      case 'officehours':
        return AvailabilityStatus.available;
      case 'busy':
        return AvailabilityStatus.busy;
      case 'inmeeting':
      case 'meeting':
        return AvailabilityStatus.inMeeting;
      case 'teaching':
      case 'inaclass':
        return AvailabilityStatus.teaching;
      case 'onbreak':
      case 'breaktime':
        return AvailabilityStatus.onBreak;
      case 'outofoffice':
      case 'away':
        return AvailabilityStatus.outOfOffice;
      case 'donotdisturb':
        return AvailabilityStatus.doNotDisturb;
      default:
        return null;
    }
  }

  String get displayName {
    switch (this) {
      case AvailabilityStatus.available:
        return 'Available';
      case AvailabilityStatus.busy:
        return 'Busy';
      case AvailabilityStatus.inMeeting:
        return 'In Meeting';
      case AvailabilityStatus.teaching:
        return 'Teaching';
      case AvailabilityStatus.onBreak:
        return 'On Break';
      case AvailabilityStatus.outOfOffice:
        return 'Out of Office';
      case AvailabilityStatus.doNotDisturb:
        return 'Do Not Disturb';
    }
  }

  IconData get icon {
    switch (this) {
      case AvailabilityStatus.available:
        return Icons.check_circle;
      case AvailabilityStatus.busy:
        return Icons.pending;
      case AvailabilityStatus.inMeeting:
        return Icons.groups;
      case AvailabilityStatus.teaching:
        return Icons.school;
      case AvailabilityStatus.onBreak:
        return Icons.coffee;
      case AvailabilityStatus.outOfOffice:
        return Icons.home;
      case AvailabilityStatus.doNotDisturb:
        return Icons.do_not_disturb;
    }
  }

  Color get color {
    switch (this) {
      case AvailabilityStatus.available:
        return const Color(0xFF4CAF50); // Green
      case AvailabilityStatus.busy:
        return const Color(0xFFFFC107); // Amber
      case AvailabilityStatus.inMeeting:
        return const Color(0xFF2196F3); // Blue
      case AvailabilityStatus.teaching:
        return const Color(0xFF9C27B0); // Purple
      case AvailabilityStatus.onBreak:
        return const Color(0xFF795548); // Brown
      case AvailabilityStatus.outOfOffice:
        return const Color(0xFF607D8B); // Blue Grey
      case AvailabilityStatus.doNotDisturb:
        return const Color(0xFFF44336); // Red
    }
  }
}

/// User model for ISKSULARS TRACK
class UserModel {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final UserRole role;
  final String? department;
  final String? position;
  final String? organization;
  final String? photoUrl;
  final String? phoneNumber;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  // Campus field - determines user's default campus
  final String campusId; // 'isulan', 'tacurong', or 'access'

  // Trackable user fields
  final bool? isTrackingEnabled;
  final String? currentStatus;
  final String? quickMessage;
  final List<String>? officeHours;

  // Availability status
  final AvailabilityStatus? availabilityStatus;
  final String? customStatusMessage;
  final DateTime? statusUpdatedAt;
  final DateTime? statusExpiresAt;

  // Notification preferences
  final NotificationPreferences? notificationPreferences;

  UserModel({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.department,
    this.position,
    this.organization,
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
    this.availabilityStatus,
    this.customStatusMessage,
    this.statusUpdatedAt,
    this.statusExpiresAt,
    this.notificationPreferences,
  });

  /// Full name getter
  String get fullName => '$firstName $lastName'.trim();

  /// Initials for avatar
  String get initials {
    String initials = '';
    if (firstName.isNotEmpty) initials += firstName[0].toUpperCase();
    if (lastName.isNotEmpty) initials += lastName[0].toUpperCase();
    return initials;
  }

  /// Check if user is a trackable user (student leader or organization
  /// officer).  Admins are NOT included — they manage the system but
  /// should not appear as pinnable leaders on the student map.
  bool get isStaff =>
      role == UserRole.studentLeader || role == UserRole.organizationOfficer;

  /// Check if user is admin
  bool get isAdmin => role == UserRole.admin;

  /// Get role as string
  String get roleString {
    switch (role) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.organizationOfficer:
        return 'Organization Officer';
      case UserRole.studentLeader:
        return 'Student Leader';
      case UserRole.student:
        return 'Student';
    }
  }

  /// Create from Firestore document (handles legacy/old user documents)
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      return _parseUserModel(doc.id, data);
    } catch (e) {
      if (kDebugMode) debugPrint('Error parsing user ${doc.id}: $e');
      // Return a safe fallback to prevent stream crashes
      return UserModel(
        id: doc.id,
        email: '',
        firstName: 'Unknown',
        lastName: 'User',
        role: UserRole.student,
        isActive: false,
        createdAt: DateTime.now(),
        campusId: 'isulan',
      );
    }
  }

  static UserModel _parseUserModel(String id, Map<String, dynamic> data) {
    // Handle email - required field, fallback to empty string
    final email = (data['email'] is String) ? data['email'] as String : '';

    // Handle names - extract from email if not present
    String firstName = (data['firstName'] is String)
        ? data['firstName'] as String
        : '';
    String lastName = (data['lastName'] is String)
        ? data['lastName'] as String
        : '';
    if (firstName.isEmpty && email.isNotEmpty) {
      firstName = email.split('@').first;
    }
    if (firstName.isEmpty) {
      firstName = 'User';
    }

    return UserModel(
      id: id,
      email: email,
      firstName: firstName,
      lastName: lastName,
      role: _parseRole(data['role']),
      department: (data['department'] is String)
          ? data['department'] as String
          : null,
      position: (data['position'] is String)
          ? data['position'] as String
          : null,
      organization: (data['organization'] is String)
          ? data['organization'] as String
          : null,
      photoUrl: (data['photoUrl'] is String)
          ? data['photoUrl'] as String
          : null,
      phoneNumber: (data['phoneNumber'] is String)
          ? data['phoneNumber'] as String
          : null,
      isActive: (data['isActive'] is bool) ? data['isActive'] as bool : true,
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      lastLoginAt: (data['lastLoginAt'] is Timestamp)
          ? (data['lastLoginAt'] as Timestamp).toDate()
          : null,
      campusId: (data['campusId'] is String)
          ? data['campusId'] as String
          : 'isulan',
      isTrackingEnabled: (data['isTrackingEnabled'] is bool)
          ? data['isTrackingEnabled'] as bool
          : false,
      currentStatus: (data['currentStatus'] is String)
          ? data['currentStatus'] as String
          : null,
      quickMessage: (data['quickMessage'] is String)
          ? data['quickMessage'] as String
          : null,
      officeHours: (data['officeHours'] is List)
          ? List<String>.from(data['officeHours'] as List)
          : null,
      availabilityStatus: AvailabilityStatusExtension.fromString(
        data['availabilityStatus'] is String
            ? data['availabilityStatus'] as String
            : data['currentStatus'] is String
            ? data['currentStatus'] as String
            : null,
      ),
      customStatusMessage: (data['customStatusMessage'] is String)
          ? data['customStatusMessage'] as String
          : null,
      statusUpdatedAt: (data['statusUpdatedAt'] is Timestamp)
          ? (data['statusUpdatedAt'] as Timestamp).toDate()
          : null,
      statusExpiresAt: (data['statusExpiresAt'] is Timestamp)
          ? (data['statusExpiresAt'] as Timestamp).toDate()
          : null,
      notificationPreferences: NotificationPreferences.fromMap(
        (data['notificationPreferences'] is Map)
            ? data['notificationPreferences'] as Map<String, dynamic>
            : null,
      ),
    );
  }

  /// Convert to Firestore document (omits null fields, uses FieldValue.delete for explicit clears)
  Map<String, dynamic> toFirestore({bool includeDeleteSentinels = true}) {
    final data = <String, dynamic>{
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'role': role.name,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
    // Use null to indicate "clear this field" — Firestore will delete it
    if (includeDeleteSentinels) {
      data['department'] = department ?? FieldValue.delete();
      data['position'] = position ?? FieldValue.delete();
      data['organization'] = organization ?? FieldValue.delete();
      data['photoUrl'] = photoUrl ?? FieldValue.delete();
      data['phoneNumber'] = phoneNumber ?? FieldValue.delete();
    } else {
      if (department != null) data['department'] = department;
      if (position != null) data['position'] = position;
      if (organization != null) data['organization'] = organization;
      if (photoUrl != null) data['photoUrl'] = photoUrl;
      if (phoneNumber != null) data['phoneNumber'] = phoneNumber;
    }
    if (isTrackingEnabled != null) {
      data['isTrackingEnabled'] = isTrackingEnabled;
    }
    if (currentStatus != null) data['currentStatus'] = currentStatus;
    data['campusId'] = campusId;
    data['searchName'] = '${firstName.toLowerCase()} ${lastName.toLowerCase()}';
    if (quickMessage != null) data['quickMessage'] = quickMessage;
    data['officeHours'] = officeHours ?? FieldValue.delete();
    if (availabilityStatus != null) {
      data['availabilityStatus'] = availabilityStatus?.name;
    }
    if (customStatusMessage != null) {
      data['customStatusMessage'] = customStatusMessage;
    }
    if (statusUpdatedAt != null) {
      data['statusUpdatedAt'] = Timestamp.fromDate(statusUpdatedAt!);
    }
    if (statusExpiresAt != null) {
      data['statusExpiresAt'] = Timestamp.fromDate(statusExpiresAt!);
    }
    if (lastLoginAt != null) {
      data['lastLoginAt'] = Timestamp.fromDate(lastLoginAt!);
    }
    if (notificationPreferences != null) {
      data['notificationPreferences'] = notificationPreferences!.toMap();
    }
    return data;
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
    String? organization,
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
    AvailabilityStatus? availabilityStatus,
    String? customStatusMessage,
    DateTime? statusUpdatedAt,
    DateTime? statusExpiresAt,
    NotificationPreferences? notificationPreferences,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      role: role ?? this.role,
      department: department ?? this.department,
      position: position ?? this.position,
      organization: organization ?? this.organization,
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
      availabilityStatus: availabilityStatus ?? this.availabilityStatus,
      customStatusMessage: customStatusMessage ?? this.customStatusMessage,
      statusUpdatedAt: statusUpdatedAt ?? this.statusUpdatedAt,
      statusExpiresAt: statusExpiresAt ?? this.statusExpiresAt,
      notificationPreferences:
          notificationPreferences ?? this.notificationPreferences,
    );
  }

  /// Parse role from string
  static UserRole _parseRole(String? roleString) {
    switch (roleString?.toLowerCase()) {
      case 'staff':
        return UserRole.studentLeader;
      case 'admin':
        return UserRole.admin;
      case 'organizationofficer':
        return UserRole.organizationOfficer;
      case 'studentleader':
        return UserRole.studentLeader;
      case 'student':
        return UserRole.student;
      default:
        if (kDebugMode && roleString != null) {
          debugPrint('⚠️ Unknown role "$roleString", defaulting to student');
        }
        return UserRole.student;
    }
  }

  /// Parse availability status from string
  @override
  String toString() {
    return 'UserModel(id: $id, email: $email, name: $fullName, role: ${role.name})';
  }
}
