import 'package:cloud_firestore/cloud_firestore.dart';
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
      
      return snapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting staff: $e');
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
      
      return snapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting staff by department: $e');
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
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromFirestore(doc))
            .toList());
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
          .where((user) =>
              user.firstName.toLowerCase().contains(queryLower) ||
              user.lastName.toLowerCase().contains(queryLower) ||
              user.fullName.toLowerCase().contains(queryLower) ||
              (user.department?.toLowerCase().contains(queryLower) ?? false))
          .toList();
    } catch (e) {
      print('Error searching staff: $e');
      return [];
    }
  }
  
  /// Update user tracking status
  Future<void> updateTrackingStatus(String oderId, bool isEnabled) async {
    try {
      await _firestore.collection('users').doc(oderId).update({
        'isTrackingEnabled': isEnabled,
      });
    } catch (e) {
      print('Error updating tracking status: $e');
    }
  }
  
  /// Update user status
  Future<void> updateUserStatus(String oderId, String status) async {
    try {
      await _firestore.collection('users').doc(oderId).update({
        'currentStatus': status,
      });
    } catch (e) {
      print('Error updating status: $e');
    }
  }
  
  /// Update quick message
  Future<void> updateQuickMessage(String oderId, String? message) async {
    try {
      await _firestore.collection('users').doc(oderId).update({
        'quickMessage': message,
      });
    } catch (e) {
      print('Error updating quick message: $e');
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
      print('Error getting departments: $e');
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
        .map((snapshot) => snapshot.docs
            .map((doc) => DepartmentModel.fromFirestore(doc))
            .toList());
  }
  
  /// Add department
  Future<void> addDepartment(DepartmentModel department) async {
    try {
      await _firestore
          .collection('departments')
          .doc(department.id)
          .set(department.toFirestore());
    } catch (e) {
      print('Error adding department: $e');
    }
  }
  
  // ==================== FACULTY WITH LOCATION ====================
  
  /// Get all faculty with their locations - Real-time stream
  /// Uses CombineLatest to listen to both users AND locations collections
  Stream<List<FacultyWithLocation>> getFacultyWithLocationsStream() {
    // Stream of staff/admin users - includeMetadataChanges for faster sync
    final usersStream = _firestore
        .collection('users')
        .where('role', whereIn: ['staff', 'admin'])
        .where('isActive', isEqualTo: true)
        .snapshots(includeMetadataChanges: true);
    
    // Stream of all locations - includeMetadataChanges for faster sync
    final locationsStream = _firestore
        .collection('locations')
        .snapshots(includeMetadataChanges: true);
    
    // Combine both streams - updates when EITHER changes
    return Rx.combineLatest2(
      usersStream,
      locationsStream,
      (QuerySnapshot<Map<String, dynamic>> usersSnapshot,
       QuerySnapshot<Map<String, dynamic>> locationsSnapshot) {
        // Build a map of userId -> location for quick lookup
        final locationMap = <String, LocationModel>{};
        for (final locDoc in locationsSnapshot.docs) {
          locationMap[locDoc.id] = LocationModel.fromFirestore(locDoc);
        }
        
        // Build result list
        final List<FacultyWithLocation> result = [];
        for (final userDoc in usersSnapshot.docs) {
          final user = UserModel.fromFirestore(userDoc);
          final location = locationMap[user.id]; // Get location if exists
          result.add(FacultyWithLocation(user: user, location: location));
        }
        
        return result;
      },
    );
  }
  
  /// Get online faculty only
  Stream<List<FacultyWithLocation>> getOnlineFacultyStream() {
    return getFacultyWithLocationsStream().map((list) =>
        list.where((f) => f.isOnline).toList());
  }
  
  // ==================== ANALYTICS (Admin) ====================
  
  /// Get total user counts
  Future<Map<String, int>> getUserCounts() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      
      int students = 0;
      int staff = 0;
      int admins = 0;
      
      for (final doc in snapshot.docs) {
        final role = doc.data()['role'] as String?;
        switch (role) {
          case 'student':
            students++;
            break;
          case 'staff':
            staff++;
            break;
          case 'admin':
            admins++;
            break;
        }
      }
      
      return {
        'students': students,
        'staff': staff,
        'admins': admins,
        'total': students + staff + admins,
      };
    } catch (e) {
      print('Error getting user counts: $e');
      return {'students': 0, 'staff': 0, 'admins': 0, 'total': 0};
    }
  }
  
  /// Get online staff count
  Future<int> getOnlineStaffCount() async {
    try {
      final snapshot = await _firestore
          .collection('locations')
          .where('isWithinCampus', isEqualTo: true)
          .get();
      
      return snapshot.docs.length;
    } catch (e) {
      print('Error getting online count: $e');
      return 0;
    }
  }
}
