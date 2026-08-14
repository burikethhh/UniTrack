import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import '../models/models.dart';

/// Firestore Database Service
class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==================== USERS ====================

  /// Get all faculty members
  Future<List<UserModel>> getAllFaculty() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', whereIn: ['studentLeader', 'organizationOfficer'])
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Error getting faculty: $e');
      return [];
    }
  }

  /// Get faculty by department
  Future<List<UserModel>> getFacultyByDepartment(String department) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', whereIn: ['studentLeader', 'organizationOfficer'])
          .where('department', isEqualTo: department)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Error getting faculty by department: $e');
      return [];
    }
  }

  /// Stream of all active faculty
  Stream<List<UserModel>> getActiveFacultyStream() {
    return _firestore
        .collection('users')
        .where('role', whereIn: ['studentLeader', 'organizationOfficer'])
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList(),
        );
  }

  /// Search faculty by name (server-side prefix match on `searchName`)
  /// Falls back to client-side filter if the index/field is missing.
  Future<List<UserModel>> searchFaculty(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final queryLower = query.toLowerCase();

      // Optimized path: server-side range query on lowercased `searchName`.
      // Requires a `searchName` field written at registration/update time.
      try {
        final snapshot = await _firestore
            .collection('users')
            .where('role', whereIn: ['studentLeader', 'organizationOfficer'])
            .where('isActive', isEqualTo: true)
            .where('searchName', isGreaterThanOrEqualTo: queryLower)
            .where('searchName', isLessThan: '$queryLower\uf8ff')
            .limit(30)
            .get();

        final exact = <UserModel>[];
        final prefix = <UserModel>[];
        for (final doc in snapshot.docs) {
          final user = UserModel.fromFirestore(doc);
          final first = user.firstName.toLowerCase();
          final last = user.lastName.toLowerCase();
          final full = user.fullName.toLowerCase();
          if (first == queryLower || last == queryLower || full == queryLower) {
            exact.add(user);
          } else if (first.startsWith(queryLower) ||
              last.startsWith(queryLower) ||
              full.startsWith(queryLower) ||
              (user.department?.toLowerCase().contains(queryLower) ?? false)) {
            prefix.add(user);
          }
        }
        return [...exact, ...prefix];
      } catch (e) {
        if (kDebugMode) {
          debugPrint('searchFaculty indexed path failed, falling back: $e');
        }
      }

      // Fallback path: client-side filter (original implementation)
      final snapshot = await _firestore
          .collection('users')
          .where('role', whereIn: ['studentLeader', 'organizationOfficer'])
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
      if (kDebugMode) debugPrint('Error searching faculty: $e');
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
      if (kDebugMode) debugPrint('Error updating tracking status: $e');
      rethrow;
    }
  }

  /// Update user status
  Future<void> updateUserStatus(
    String userId,
    String status, {
    AvailabilityStatus? availabilityStatus,
    DateTime? statusUpdatedAt,
    DateTime? statusExpiresAt,
  }) async {
    try {
      final data = <String, dynamic>{
        'currentStatus': status,
        if (availabilityStatus != null)
          'availabilityStatus': availabilityStatus.name,
        if (statusUpdatedAt != null)
          'statusUpdatedAt': Timestamp.fromDate(statusUpdatedAt),
        if (statusExpiresAt != null)
          'statusExpiresAt': Timestamp.fromDate(statusExpiresAt),
      };
      await _firestore
          .collection('users')
          .doc(userId)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('Error updating status: $e');
      rethrow;
    }
  }

  /// Update quick message
  Future<void> updateQuickMessage(String userId, String? message) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'quickMessage': message ?? FieldValue.delete(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('Error updating quick message: $e');
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
      if (kDebugMode) debugPrint('Error getting departments: $e');
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
      if (kDebugMode) debugPrint('Error adding department: $e');
    }
  }

  // ==================== FACULTY WITH LOCATION ====================

  /// Get all faculty with their locations - Real-time stream
  /// Uses CombineLatest to listen to both users AND locations collections.
  /// When [viewerRole] is [UserRole.student], off-campus locations are
  /// stripped (set to null) so students never receive raw coordinates
  /// for faculty outside campus boundaries.
  ///
  /// NOTE: Firebase `whereIn` caps at 30 literals. For larger datasets,
  /// chunk the stream or add server-side filtering via Cloud Functions.
  Stream<List<FacultyWithLocation>> getFacultyWithLocationsStream({
    UserRole? viewerRole,
    String? viewerCampusId,
  }) {
    final usersStream = _firestore
        .collection('users')
        .where('role', whereIn: ['studentLeader', 'organizationOfficer'])
        .where('isActive', isEqualTo: true)
        .snapshots();

    // Cache location data and previous user IDs to avoid re-subscribing
    // to location streams when only user attributes change.
    List<String>? prevUserIds;
    Map<String, LocationModel> cachedLocations = {};

    return usersStream.switchMap((usersSnapshot) {
      final userIds = usersSnapshot.docs.map((d) => d.id).toList()..sort();

      final idsChanged =
          prevUserIds == null || !_listEquals(prevUserIds!, userIds);
      prevUserIds = userIds;

      if (userIds.isEmpty) {
        cachedLocations = {};
        return Stream.value(
          usersSnapshot.docs
              .map(
                (d) => FacultyWithLocation(
                  user: UserModel.fromFirestore(d),
                  location: null,
                ),
              )
              .toList(),
        );
      }

      if (!idsChanged) {
        // User IDs unchanged — build result from cached locations (no new subscriptions)
        final List<FacultyWithLocation> result = [];
        for (final userDoc in usersSnapshot.docs) {
          try {
            final user = UserModel.fromFirestore(userDoc);
            LocationModel? location = cachedLocations[user.id];
            if (viewerRole == UserRole.student &&
                location != null &&
                !(location.isWithinCampus)) {
              location = null;
            }
            result.add(FacultyWithLocation(user: user, location: location));
          } catch (e) {
            if (kDebugMode) {
              debugPrint('Skipping bad user doc ${userDoc.id}: $e');
            }
          }
        }
        return Stream.value(result);
      }

      // User IDs changed — re-subscribe to location streams
      final locationStreams = <Stream<QuerySnapshot>>[];
      for (var i = 0; i < userIds.length; i += 30) {
        final chunk = userIds.sublist(i, (i + 30).clamp(0, userIds.length));
        if (viewerRole == UserRole.student) {
          // Firestore rules are not filters. Use separate constrained streams
          // for university-wide and campus-only visibility.
          final baseQuery = _firestore
              .collection('locations')
              .where(FieldPath.documentId, whereIn: chunk)
              .where('isWithinCampus', isEqualTo: true);
          locationStreams.add(
            baseQuery
                .where('visibilityScope', isEqualTo: 'universityWide')
                .snapshots(),
          );
          if (viewerCampusId != null) {
            locationStreams.add(
              baseQuery
                  .where('visibilityScope', isEqualTo: 'campusOnly')
                  .where('locationCampusId', isEqualTo: viewerCampusId)
                  .snapshots(),
            );
          }
          continue;
        }
        locationStreams.add(
          _firestore
              .collection('locations')
              .where(FieldPath.documentId, whereIn: chunk)
              .snapshots(),
        );
      }

      if (locationStreams.isEmpty) {
        cachedLocations = {};
        return Stream.value(
          usersSnapshot.docs
              .map(
                (d) => FacultyWithLocation(
                  user: UserModel.fromFirestore(d),
                  location: null,
                ),
              )
              .toList(),
        );
      }

      return Rx.combineLatest(locationStreams, (List<QuerySnapshot> snaps) {
        cachedLocations = {};
        for (final snap in snaps) {
          for (final locDoc in snap.docs) {
            final loc = LocationModel.tryFromFirestore(locDoc);
            if (loc != null) {
              cachedLocations[locDoc.id] = loc;
            }
          }
        }

        final List<FacultyWithLocation> result = [];
        for (final userDoc in usersSnapshot.docs) {
          try {
            final user = UserModel.fromFirestore(userDoc);
            LocationModel? location = cachedLocations[user.id];
            if (viewerRole == UserRole.student &&
                location != null &&
                !(location.isWithinCampus)) {
              location = null;
            }
            result.add(FacultyWithLocation(user: user, location: location));
          } catch (e) {
            if (kDebugMode) {
              debugPrint('Skipping bad user doc ${userDoc.id}: $e');
            }
          }
        }
        return result;
      });
    });
  }

  /// Simple list equality check for caching
  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Get online faculty only
  Stream<List<FacultyWithLocation>> getOnlineFacultyStream() {
    return getFacultyWithLocationsStream().map(
      (list) => list.where((f) => f.isOnline).toList(),
    );
  }

  /// Get ALL users (students + leaders + officers + admins) with their locations - Admin Live Monitor
  /// Unlike getFacultyWithLocationsStream, this includes ALL roles.
  /// Same chunked `whereIn` approach as above to avoid full `locations` collection reads.
  Stream<List<FacultyWithLocation>> getAllUsersWithLocationsStream() {
    final usersStream = _firestore
        .collection('users')
        .where('isActive', isEqualTo: true)
        .snapshots();

    return usersStream.asyncExpand((usersSnapshot) {
      final userIds = usersSnapshot.docs.map((d) => d.id).toList();
      if (userIds.isEmpty) {
        return Stream.value(
          usersSnapshot.docs
              .map(
                (d) => FacultyWithLocation(
                  user: UserModel.fromFirestore(d),
                  location: null,
                ),
              )
              .toList(),
        );
      }

      final locationStreams = <Stream<QuerySnapshot>>[];
      for (var i = 0; i < userIds.length; i += 30) {
        final chunk = userIds.sublist(i, (i + 30).clamp(0, userIds.length));
        locationStreams.add(
          _firestore
              .collection('locations')
              .where(FieldPath.documentId, whereIn: chunk)
              .snapshots(),
        );
      }

      if (locationStreams.isEmpty) {
        return Stream.value(
          usersSnapshot.docs
              .map(
                (d) => FacultyWithLocation(
                  user: UserModel.fromFirestore(d),
                  location: null,
                ),
              )
              .toList(),
        );
      }

      return Rx.combineLatest(locationStreams, (List<QuerySnapshot> snaps) {
        final mergedMap = <String, LocationModel>{};
        for (final snap in snaps) {
          for (final locDoc in snap.docs) {
            final loc = LocationModel.tryFromFirestore(locDoc);
            if (loc != null) {
              mergedMap[locDoc.id] = loc;
            }
          }
        }

        final List<FacultyWithLocation> result = [];
        for (final userDoc in usersSnapshot.docs) {
          try {
            final user = UserModel.fromFirestore(userDoc);
            final location = mergedMap[user.id];
            result.add(FacultyWithLocation(user: user, location: location));
          } catch (e) {
            if (kDebugMode) {
              debugPrint('Skipping bad user doc ${userDoc.id}: $e');
            }
          }
        }
        return result;
      });
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
      final adminsCount = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .count()
          .get();
      final studentLeadersCount = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'studentLeader')
          .count()
          .get();
      final orgOfficersCount = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'organizationOfficer')
          .count()
          .get();

      final students = studentsCount.count ?? 0;
      final admins = adminsCount.count ?? 0;
      final studentLeaders = studentLeadersCount.count ?? 0;
      final orgOfficers = orgOfficersCount.count ?? 0;
      final faculty = studentLeaders + orgOfficers;

      return {
        'students': students,
        'faculty': faculty,
        'admins': admins,
        'total': students + faculty + admins,
      };
    } catch (e) {
      if (kDebugMode) debugPrint('Error getting user counts: $e');
      return {'students': 0, 'faculty': 0, 'admins': 0, 'total': 0};
    }
  }
}
