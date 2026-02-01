import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

/// Authentication Provider for state management
class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  // ignore: unused_field
  final DatabaseService _databaseService;
  
  AuthProvider({
    required AuthService authService,
    required DatabaseService databaseService,
  }) : _authService = authService,
       _databaseService = databaseService {
    _init();
  }
  
  UserModel? _user;
  bool _isLoading = true;
  String? _error;
  
  // Getters
  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;
  bool get isAuthenticated => _user != null;
  bool get isStaff => _user?.isStaff ?? false;
  bool get isAdmin => _user?.isAdmin ?? false;
  UserRole? get role => _user?.role;
  
  /// Initialize - check if user is already logged in
  void _init() {
    _checkAuthState();
  }
  
  Future<void> _checkAuthState() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      if (_authService.currentUser != null) {
        _user = await _authService.getCurrentUserModel();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Sign in with email and password
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      _user = await _authService.signInWithEmailPassword(
        email: email,
        password: password,
      );
      _isLoading = false;
      notifyListeners();
      return _user != null;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  /// Register new user
  Future<bool> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required UserRole role,
    String? department,
    String? position,
    String campusId = 'isulan', // Default campus
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      _user = await _authService.registerWithEmailPassword(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        role: role,
        department: department,
        position: position,
        campusId: campusId,
      );
      _isLoading = false;
      notifyListeners();
      return _user != null;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  /// Update user profile
  Future<void> updateProfile(UserModel updatedUser) async {
    try {
      await _authService.updateUserProfile(updatedUser);
      _user = updatedUser;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
  
  /// Send password reset email
  Future<bool> sendPasswordReset(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await _authService.sendPasswordResetEmail(email);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  /// Sign out
  Future<void> signOut() async {
    await _authService.signOut();
    _user = null;
    _error = null;
    notifyListeners();
  }
  
  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  /// Refresh user data
  Future<void> refreshUser() async {
    if (_authService.currentUser != null) {
      _user = await _authService.getCurrentUserModel();
      notifyListeners();
    }
  }
}
