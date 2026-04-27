import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import '../models/models.dart';

/// Firestore Database Service
class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==================== USERS ====================

  /// Get all staff members
  Future<List<UserModel>> getAllStaff() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', whereIn: ['staff', 'admin'])
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getting staff: $e');
      return [];
    }
  }

  /// Get staff by department
  Future<List<UserModel>> getStaffByDepartment(String department) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', whereIn: ['staff', 'admin'])
          .where('department', isEqualTo: department)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getting staff by department: $e');
      return [];
    }
  }

  /// Stream of all active staff
  Stream<List<UserModel>> getActiveStaffStream() {
    return _firestore
        .collection('users')
        .where('role', whereIn: ['staff', 'admin'])
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList(),
        );
  }

  /// Search staff by name
  Future<List<UserModel>> searchStaff(String query) async {
    try {
      final queryLower = query.toLowerCase();
      final snapshot = await _firestore
          .collection('users')
          .where('role', whereIn: ['staff', 'admin'])
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .where(
            (user) =>
                user.firstName.toLowerCase().contains(queryLower) ||
                user.lastName.toLowerCase().contains(queryLower) ||
                user.fullName.toLowerCase().contains(queryLower) ||
                (user.department?.toLowerCase().contains(queryLower) ?? false),
          )
          .toList();
    } catch (e) {
      debugPrint('Error searching staff: $e');
      return [];
    }
  }

  /// Update user tracking status
  Future<void> updateTrackingStatus(String userId, bool isEnabled) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'isTrackingEnabled': isEnabled,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating tracking status: $e');
      rethrow;
    }
  }

  /// Update user status
  Future<void> updateUserStatus(String userId, String status) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'currentStatus': status,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating status: $e');
      rethrow;
    }
  }

  /// Update quick message
  Future<void> updateQuickMessage(String userId, String? message) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'quickMessage': message,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating quick message: $e');
      rethrow;
    }
  }

  // ==================== DEPARTMENTS ====================

  /// Get all departments
  Future<List<DepartmentModel>> getAllDepartments() async {
    try {
      final snapshot = await _firestore
          .collection('departments')
          .where('isActive', isEqualTo: true)
          .orderBy('name')
          .get();

      return snapshot.docs
          .map((doc) => DepartmentModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting departments: $e');
      return [];
    }
  }

  /// Stream of departments
  Stream<List<DepartmentModel>> getDepartmentsStream() {
    return _firestore
        .collection('departments')
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => DepartmentModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// Add department
  Future<void> addDepartment(DepartmentModel department) async {
    try {
      await _firestore
          .collection('departments')
          .doc(department.id)
          .set(department.toFirestore());
    } catch (e) {
      debugPrint('Error adding department: $e');
    }
  }

  // ==================== FACULTY WITH LOCATION ====================

  /// Get all faculty with their locations - Real-time stream
  /// Uses CombineLatest to listen to both users AND locations collections.
  /// When [viewerRole] is [UserRole.student], off-campus locations are
  /// stripped (set to null) so students never receive raw coordinates
  /// for faculty outside campus boundaries.
  Stream<List<FacultyWithLocation>> getFacultyWithLocationsStream({
    UserRole? viewerRole,
  }) {
    // Stream of staff/admin users
    final usersStream = _firestore
        .collection('users')
        .where('role', whereIn: ['staff', 'admin'])
        .where('isActive', isEqualTo: true)
        .snapshots();

    // Stream of all locations
    final locationsStream = _firestore.collection('locations').snapshots();

    // Combine both streams - updates when EITHER changes
    return Rx.combineLatest2(usersStream, locationsStream, (
      QuerySnapshot<Map<String, dynamic>> usersSnapshot,
      QuerySnapshot<Map<String, dynamic>> locationsSnapshot,
    ) {
      // Build a map of userId -> location for quick lookup
      // Wrap each doc in try-catch so one bad document doesn't crash the stream
      final locationMap = <String, LocationModel>{};
      for (final locDoc in locationsSnapshot.docs) {
        final loc = LocationModel.tryFromFirestore(locDoc);
        if (loc != null) {
          locationMap[locDoc.id] = loc;
        }
      }

      // Build result list
      final List<FacultyWithLocation> result = [];
      for (final userDoc in usersSnapshot.docs) {
        try {
          final user = UserModel.fromFirestore(userDoc);
          LocationModel? location =
              locationMap[user.id]; // Get location if exists

          // Privacy: strip off-campus locations for student viewers
          // so they never receive raw coordinates outside campus boundaries
          if (viewerRole == UserRole.student &&
              location != null &&
              !(location.isWithinCampus)) {
            location = null;
          }

          result.add(FacultyWithLocation(user: user, location: location));
        } catch (e) {
          debugPrint('Skipping bad user doc ${userDoc.id}: $e');
        }
      }

      return result;
    });
  }

  /// Get online faculty only
  Stream<List<FacultyWithLocation>> getOnlineFacultyStream() {
    return getFacultyWithLocationsStream().map(
      (list) => list.where((f) => f.isOnline).toList(),
    );
  }

  /// Get ALL users (students + staff + admin) with their locations - Admin Live Monitor
  /// Unlike getFacultyWithLocationsStream, this includes ALL roles
  Stream<List<FacultyWithLocation>> getAllUsersWithLocationsStream() {
    // Stream of ALL active users (no role filter)
    final usersStream = _firestore
        .collection('users')
        .where('isActive', isEqualTo: true)
        .snapshots();

    // Stream of all locations
    final locationsStream = _firestore.collection('locations').snapshots();

    return Rx.combineLatest2(usersStream, locationsStream, (
      QuerySnapshot<Map<String, dynamic>> usersSnapshot,
      QuerySnapshot<Map<String, dynamic>> locationsSnapshot,
    ) {
      // Wrap each doc in try-catch so one bad document doesn't crash the stream
      final locationMap = <String, LocationModel>{};
      for (final locDoc in locationsSnapshot.docs) {
        final loc = LocationModel.tryFromFirestore(locDoc);
        if (loc != null) {
          locationMap[locDoc.id] = loc;
        }
      }

      final List<FacultyWithLocation> result = [];
      for (final userDoc in usersSnapshot.docs) {
        try {
          final user = UserModel.fromFirestore(userDoc);
          final location = locationMap[user.id];
          result.add(FacultyWithLocation(user: user, location: location));
        } catch (e) {
          debugPrint('Skipping bad user doc ${userDoc.id}: $e');
        }
      }

      return result;
    });
  }

  // ==================== ANALYTICS (Admin) ====================

  /// Get total user counts using aggregation queries (avoids downloading all docs)
  Future<Map<String, int>> getUserCounts() async {
    try {
      final studentsCount = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'student')
          .count()
          .get();
      final staffCount = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'staff')
          .count()
          .get();
      final adminsCount = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .count()
          .get();

      final students = studentsCount.count ?? 0;
      final staff = staffCount.count ?? 0;
      final admins = adminsCount.count ?? 0;

      return {
        'students': students,
        'staff': staff,
        'admins': admins,
        'total': students + staff + admins,
      };
    } catch (e) {
      debugPrint('Error getting user counts: $e');
      return {'students': 0, 'staff': 0, 'admins': 0, 'total': 0};
    }
  }
}
