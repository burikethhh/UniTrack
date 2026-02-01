import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

/// Statistics model for admin dashboard
class AppStatistics {
  final int totalUsers;
  final int totalStudents;
  final int totalStaff;
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
    this.totalStaff = 0,
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
      userId: data['userId'] ?? '',
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

  // Getters
  List<UserModel> get allUsers => _allUsers;
  List<UserModel> get filteredUsers => _filteredUsers;
  List<UserModel> get students => _allUsers.where((u) => u.role == UserRole.student).toList();
  List<UserModel> get staff => _allUsers.where((u) => u.role == UserRole.staff).toList();
  List<UserModel> get admins => _allUsers.where((u) => u.role == UserRole.admin).toList();
  List<UserModel> get bannedUsers => _allUsers.where((u) => !u.isActive).toList();
  AppStatistics get statistics => _statistics;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  UserRole? get roleFilter => _roleFilter;
  String? get campusFilter => _campusFilter;
  bool get showBannedOnly => _showBannedOnly;

  /// Initialize and load all data
  Future<void> initialize() async {
    await Future.wait([
      loadAllUsers(),
      loadStatistics(),
    ]);
  }

  /// Load all users from Firestore
  Future<void> loadAllUsers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('users')
          .orderBy('createdAt', descending: true)
          .get();

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

  /// Load statistics
  Future<void> loadStatistics() async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekStart = todayStart.subtract(const Duration(days: 7));
      final monthStart = DateTime(now.year, now.month, 1);

      // Count by role
      int students = 0, staff = 0, admins = 0, banned = 0;
      int activeToday = 0, newThisWeek = 0, newThisMonth = 0;
      Map<String, int> byDepartment = {};
      Map<String, int> byCampus = {};

      for (final user in _allUsers) {
        // Role counts
        switch (user.role) {
          case UserRole.student:
            students++;
            break;
          case UserRole.staff:
            staff++;
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

      // Get online count from locations
      final locationsSnapshot = await _firestore
          .collection('locations')
          .where('isOnline', isEqualTo: true)
          .get();

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
        totalStaff: staff,
        totalAdmins: admins,
        activeToday: activeToday,
        newUsersThisWeek: newThisWeek,
        newUsersThisMonth: newThisMonth,
        bannedUsers: banned,
        onlineNow: locationsSnapshot.docs.length,
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
        final matchesDept = user.department?.toLowerCase().contains(query) ?? false;
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

  /// Ban a user (disable account)
  Future<bool> banUser(String userId, {String? reason}) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isActive': false,
        'bannedAt': FieldValue.serverTimestamp(),
        'banReason': reason,
      });

      // Log activity
      await _logActivity(
        userId: userId,
        action: 'USER_BANNED',
        details: reason ?? 'Account disabled by admin',
      );

      // Update local state
      final index = _allUsers.indexWhere((u) => u.id == userId);
      if (index != -1) {
        _allUsers[index] = _allUsers[index].copyWith(isActive: false);
        _applyFilters();
        await loadStatistics();
        notifyListeners();
      }

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Unban a user (re-enable account)
  Future<bool> unbanUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isActive': true,
        'bannedAt': null,
        'banReason': null,
      });

      // Log activity
      await _logActivity(
        userId: userId,
        action: 'USER_UNBANNED',
        details: 'Account re-enabled by admin',
      );

      // Update local state
      final index = _allUsers.indexWhere((u) => u.id == userId);
      if (index != -1) {
        _allUsers[index] = _allUsers[index].copyWith(isActive: true);
        _applyFilters();
        await loadStatistics();
        notifyListeners();
      }

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Delete a user permanently
  Future<bool> deleteUser(String userId) async {
    try {
      // Delete user document
      await _firestore.collection('users').doc(userId).delete();

      // Delete user's location if exists
      await _firestore.collection('locations').doc(userId).delete();

      // Delete user's notifications
      final notifSnapshot = await _firestore
          .collection('notifications')
          .where('recipientId', isEqualTo: userId)
          .get();
      for (final doc in notifSnapshot.docs) {
        await doc.reference.delete();
      }

      // Log activity
      await _logActivity(
        userId: userId,
        action: 'USER_DELETED',
        details: 'Account permanently deleted by admin',
      );

      // Update local state
      _allUsers.removeWhere((u) => u.id == userId);
      _applyFilters();
      await loadStatistics();
      notifyListeners();

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Update user role
  Future<bool> updateUserRole(String userId, UserRole newRole) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'role': newRole.name,
      });

      // Log activity
      await _logActivity(
        userId: userId,
        action: 'ROLE_CHANGED',
        details: 'Role changed to ${newRole.name}',
      );

      // Update local state
      final index = _allUsers.indexWhere((u) => u.id == userId);
      if (index != -1) {
        _allUsers[index] = _allUsers[index].copyWith(role: newRole);
        _applyFilters();
        await loadStatistics();
        notifyListeners();
      }

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Update user details
  Future<bool> updateUser(String userId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(userId).update(data);

      // Reload users
      await loadAllUsers();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Log admin activity
  Future<void> _logActivity({
    required String userId,
    required String action,
    String? details,
  }) async {
    try {
      final user = _allUsers.firstWhere(
        (u) => u.id == userId,
        orElse: () => UserModel(
          id: userId,
          email: '',
          firstName: 'Unknown',
          lastName: 'User',
          role: UserRole.student,
          createdAt: DateTime.now(),
        ),
      );

      await _firestore.collection('activity_logs').add({
        'userId': userId,
        'userName': user.fullName,
        'action': action,
        'details': details,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error logging activity: $e');
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
