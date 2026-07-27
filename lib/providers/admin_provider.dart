import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../services/activity_log_service.dart';

/// Statistics model for admin dashboard
class AppStatistics {
  final int totalUsers;
  final int totalStudents;
  final int totalStudentLeaders;
  final int totalOrgOfficers;
  final int totalAdmins;
  final int activeToday;
  final int newUsersThisWeek;
  final int newUsersThisMonth;
  final int bannedUsers;
  final int onlineNow;
  final Map<String, int> usersByDepartment;
  final Map<String, int> usersByCampus;
  final List<ActivityLog> recentActivity;

  AppStatistics({
    this.totalUsers = 0,
    this.totalStudents = 0,
    this.totalStudentLeaders = 0,
    this.totalOrgOfficers = 0,
    this.totalAdmins = 0,
    this.activeToday = 0,
    this.newUsersThisWeek = 0,
    this.newUsersThisMonth = 0,
    this.bannedUsers = 0,
    this.onlineNow = 0,
    this.usersByDepartment = const {},
    this.usersByCampus = const {},
    this.recentActivity = const [],
  });
}

/// Activity log entry
class ActivityLog {
  final String id;
  final String userId;
  final String userName;
  final String action;
  final String? details;
  final DateTime timestamp;

  ActivityLog({
    required this.id,
    required this.userId,
    required this.userName,
    required this.action,
    this.details,
    required this.timestamp,
  });

  factory ActivityLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ActivityLog(
      id: doc.id,
      userId: data['actorId'] ?? '',
      userName: data['userName'] ?? 'Unknown',
      action: data['action'] ?? '',
      details: data['details'],
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Admin Provider for managing all users and statistics
class AdminProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<UserModel> _allUsers = [];
  List<UserModel> _filteredUsers = [];
  AppStatistics _statistics = AppStatistics();
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  UserRole? _roleFilter;
  String? _campusFilter;
  bool _showBannedOnly = false;
  String _sortBy = 'name'; // 'name', 'date', 'role', 'campus'

  // Pagination
  static const int _pageSize = 100;
  DocumentSnapshot? _lastDocument;
  bool _hasMoreUsers = true;

  // Getters
  List<UserModel> get allUsers => _allUsers;
  List<UserModel> get filteredUsers => _filteredUsers;
  List<UserModel> get students =>
      _allUsers.where((u) => u.role == UserRole.student).toList();
  List<UserModel> get studentLeaders =>
      _allUsers.where((u) => u.role == UserRole.studentLeader).toList();
  List<UserModel> get orgOfficers =>
      _allUsers.where((u) => u.role == UserRole.organizationOfficer).toList();
  List<UserModel> get admins =>
      _allUsers.where((u) => u.role == UserRole.admin).toList();
  List<UserModel> get bannedUsers =>
      _allUsers.where((u) => !u.isActive).toList();
  AppStatistics get statistics => _statistics;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  UserRole? get roleFilter => _roleFilter;
  String? get campusFilter => _campusFilter;
  bool get showBannedOnly => _showBannedOnly;
  bool get hasMoreUsers => _hasMoreUsers;

  /// Initialize and load all data
  Future<void> initialize() async {
    await Future.wait([loadAllUsers(), loadStatistics()]);
  }

  /// Load all users from Firestore
  Future<void> loadAllUsers() async {
    _isLoading = true;
    _error = null;
    _allUsers = [];
    _lastDocument = null;
    _hasMoreUsers = true;
    notifyListeners();

    try {
      Query query = _firestore
          .collection('users')
          .orderBy('createdAt', descending: true)
          .limit(_pageSize);

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
        _hasMoreUsers = snapshot.docs.length == _pageSize;
      } else {
        _hasMoreUsers = false;
      }

      _allUsers = snapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();

      _applyFilters();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load next page of users (cursor-based pagination)
  Future<void> loadMoreUsers() async {
    if (!_hasMoreUsers || _isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      Query query = _firestore
          .collection('users')
          .orderBy('createdAt', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_pageSize);

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
        _hasMoreUsers = snapshot.docs.length == _pageSize;
        _allUsers.addAll(
          snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList(),
        );
      } else {
        _hasMoreUsers = false;
      }

      _applyFilters();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load statistics
  Future<void> loadStatistics() async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekStart = todayStart.subtract(const Duration(days: 7));
      final monthStart = DateTime(now.year, now.month, 1);

      // Count by role
      int students = 0, studentLeaders = 0, orgOfficers = 0, admins = 0, banned = 0;
      int activeToday = 0, newThisWeek = 0, newThisMonth = 0;
      Map<String, int> byDepartment = {};
      Map<String, int> byCampus = {};

      for (final user in _allUsers) {
        // Role counts
        switch (user.role) {
          case UserRole.student:
            students++;
            break;
          case UserRole.studentLeader:
            studentLeaders++;
            break;
          case UserRole.organizationOfficer:
            orgOfficers++;
            break;
          case UserRole.admin:
            admins++;
            break;
        }

        // Banned count
        if (!user.isActive) banned++;

        // Active today
        if (user.lastLoginAt != null && user.lastLoginAt!.isAfter(todayStart)) {
          activeToday++;
        }

        // New this week
        if (user.createdAt.isAfter(weekStart)) {
          newThisWeek++;
        }

        // New this month
        if (user.createdAt.isAfter(monthStart)) {
          newThisMonth++;
        }

        // By department
        final dept = user.department ?? 'Unassigned';
        byDepartment[dept] = (byDepartment[dept] ?? 0) + 1;

        // By campus
        byCampus[user.campusId] = (byCampus[user.campusId] ?? 0) + 1;
      }

      // Get online count from locations using aggregation (avoid downloading all docs)
      // Count ALL location docs — leaders/officers outside campus boundaries are still online
      final onlineCountResult = await _firestore
          .collection('locations')
          .count()
          .get();
      final onlineNow = onlineCountResult.count ?? 0;

      // Load recent activity
      final activitySnapshot = await _firestore
          .collection('activity_logs')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      final recentActivity = activitySnapshot.docs
          .map((doc) => ActivityLog.fromFirestore(doc))
          .toList();

      _statistics = AppStatistics(
        totalUsers: _allUsers.length,
        totalStudents: students,
        totalStudentLeaders: studentLeaders,
        totalOrgOfficers: orgOfficers,
        totalAdmins: admins,
        activeToday: activeToday,
        newUsersThisWeek: newThisWeek,
        newUsersThisMonth: newThisMonth,
        bannedUsers: banned,
        onlineNow: onlineNow,
        usersByDepartment: byDepartment,
        usersByCampus: byCampus,
        recentActivity: recentActivity,
      );

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading statistics: $e');
    }
  }

  /// Search users
  void search(String query) {
    _searchQuery = query;
    _applyFilters();
    notifyListeners();
  }

  /// Set role filter
  void setRoleFilter(UserRole? role) {
    _roleFilter = role;
    _applyFilters();
    notifyListeners();
  }

  /// Set campus filter
  void setCampusFilter(String? campus) {
    _campusFilter = campus;
    _applyFilters();
    notifyListeners();
  }

  /// Toggle banned only
  void setShowBannedOnly(bool value) {
    _showBannedOnly = value;
    _applyFilters();
    notifyListeners();
  }

  /// Set sort order
  void setSortBy(String sort) {
    _sortBy = sort;
    _applyFilters();
    notifyListeners();
  }

  /// Apply all filters
  void _applyFilters() {
    _filteredUsers = _allUsers.where((user) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesName = user.fullName.toLowerCase().contains(query);
        final matchesEmail = user.email.toLowerCase().contains(query);
        final matchesDept =
            user.department?.toLowerCase().contains(query) ?? false;
        if (!matchesName && !matchesEmail && !matchesDept) return false;
      }

      // Role filter
      if (_roleFilter != null && user.role != _roleFilter) return false;

      // Campus filter
      if (_campusFilter != null && user.campusId != _campusFilter) return false;

      // Banned only
      if (_showBannedOnly && user.isActive) return false;

      return true;
    }).toList();

    // Sort
    switch (_sortBy) {
      case 'name':
        _filteredUsers.sort((a, b) => a.fullName.compareTo(b.fullName));
        break;
      case 'date':
        _filteredUsers.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'role':
        _filteredUsers.sort((a, b) => a.role.index.compareTo(b.role.index));
        break;
      case 'campus':
        _filteredUsers.sort((a, b) => a.campusId.compareTo(b.campusId));
        break;
    }
  }

  /// Clear all filters
  void clearFilters() {
    _searchQuery = '';
    _roleFilter = null;
    _campusFilter = null;
    _showBannedOnly = false;
    _applyFilters();
    notifyListeners();
  }

  /// Ban a user (set isActive=false in Firestore; login flow blocks them)
  Future<bool> banUser(String userId, {String? reason}) async {
    try {
      final updates = <String, dynamic>{
        'isActive': false,
        'bannedAt': FieldValue.serverTimestamp(),
      };
      if (reason != null) updates['banReason'] = reason;
      await _firestore.collection('users').doc(userId).update(updates);

      _updateLocalUser(userId, (u) => u.copyWith(isActive: false));
      ActivityLogService().logBanUser(userId, reason: reason);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Unban a user (set isActive=true)
  Future<bool> unbanUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isActive': true,
        'bannedAt': FieldValue.delete(),
        'banReason': FieldValue.delete(),
      });

      _updateLocalUser(userId, (u) => u.copyWith(isActive: true));
      ActivityLogService().logUnbanUser(userId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Delete a user document from Firestore (Firebase Auth account becomes orphaned
  /// — user can't log in because Firestore rules + isActive check block them).
  Future<bool> deleteUser(String userId) async {
    try {
      final batch = _firestore.batch();

      // Delete user doc
      batch.delete(_firestore.collection('users').doc(userId));

      // Delete location doc if exists
      batch.delete(_firestore.collection('locations').doc(userId));

      // Delete notifications where user is recipient or sender
      final receivedSnap = await _firestore
          .collection('notifications')
          .where('recipientId', isEqualTo: userId)
          .limit(499)
          .get();
      final sentSnap = await _firestore
          .collection('notifications')
          .where('senderId', isEqualTo: userId)
          .limit(499)
          .get();

      for (final doc in [...receivedSnap.docs, ...sentSnap.docs]) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      _allUsers.removeWhere((u) => u.id == userId);
      _applyFilters();
      await loadStatistics();
      ActivityLogService().logDeleteUser(userId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Update user role (admin-only, secured by Firestore rules)
  Future<bool> updateUserRole(String userId, UserRole newRole) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'role': newRole.name,
      });

      _updateLocalUser(userId, (u) => u.copyWith(role: newRole));
      ActivityLogService().logRoleChange(userId, newRole.name);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Helper: update a single user in the local cache and refresh stats
  void _updateLocalUser(String userId, UserModel Function(UserModel) updater) {
    final index = _allUsers.indexWhere((u) => u.id == userId);
    if (index != -1) {
      _allUsers[index] = updater(_allUsers[index]);
      _applyFilters();
      loadStatistics();
      notifyListeners();
    }
  }

  /// Update user details
  Future<bool> updateUser(String userId, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .set(data, SetOptions(merge: true));

      // Reload users
      await loadAllUsers();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Get user by ID
  UserModel? getUserById(String userId) {
    try {
      return _allUsers.firstWhere((u) => u.id == userId);
    } catch (_) {
      return null;
    }
  }

  /// Refresh all data
  Future<void> refresh() async {
    await initialize();
  }
}
