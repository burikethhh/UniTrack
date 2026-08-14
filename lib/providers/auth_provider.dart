import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/push_notification_service.dart';
import 'location_provider.dart';

/// Authentication Provider for state management
class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final LocationProvider? _locationProvider;
  StreamSubscription? _authStateSubscription;
  StreamSubscription? _userDocSubscription; // Real-time Firestore role/status watcher
  bool _isSigningIn =
      false; // Guard to prevent auth listener interference during sign-in

  AuthProvider({
    required AuthService authService,
    LocationProvider? locationProvider,
  }) : _authService = authService,
       _locationProvider = locationProvider {
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

  /// Reset loading state (useful for timeout recovery)
  void resetLoading() {
    _isLoading = false;
    _isSigningIn = false;
    notifyListeners();
  }

  /// Initialize - check if user is already logged in and listen for auth changes
  void _init() {
    _checkAuthState();
    _listenToAuthChanges();
  }

  /// Listen to Firebase Auth state changes as a safety net.
  /// Always refreshes the user profile from Firestore when Firebase auth
  /// fires, ensuring stale or fallback user data is corrected.
  void _listenToAuthChanges() {
    _authStateSubscription = _authService.authStateChanges.listen((
      firebaseUser,
    ) async {
      // Skip if we're in the middle of signIn() — it handles its own state
      if (_isSigningIn) {
        if (kDebugMode) {
          debugPrint('Auth state listener: skipping (signIn in progress)');
        }
        return;
      }
      if (firebaseUser != null && !_isLoading) {
        // Always refresh profile from Firestore — this corrects stale/fallback data
        if (kDebugMode) {
          debugPrint(
            'Auth state listener: Firebase user detected, refreshing profile...',
          );
        }
        try {
          final freshUser = await _authService.getCurrentUserModel().timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              if (kDebugMode) {
                debugPrint('Auth listener: getCurrentUserModel timed out');
              }
              return null;
            },
          );
          if (freshUser != null &&
              (freshUser.role != _user?.role ||
                  freshUser.isActive != _user?.isActive ||
                  freshUser.campusId != _user?.campusId ||
                  freshUser.currentStatus != _user?.currentStatus ||
                  _user == null)) {
            _user = freshUser;
            if (kDebugMode) {
              debugPrint(
                'Auth listener: Profile refreshed for ${_user!.fullName} (role: ${_user!.role})',
              );
            }
            notifyListeners();
          }
        } catch (e) {
          if (kDebugMode) debugPrint('Auth listener error: $e');
        }
      } else if (firebaseUser == null && _user != null) {
        // User signed out externally
        _user = null;
        notifyListeners();
      }
    });
  }

  /// Subscribe to real-time Firestore changes for the signed-in user.
  /// Handles role promotions, bans, and isActive changes from the Admin.
  void _subscribeToUserDoc(String userId) {
    _userDocSubscription?.cancel();
    _userDocSubscription = _authService.userStream(userId).listen(
      (updatedUser) {
        if (updatedUser == null) return;
        // Only notify if something meaningful changed
        final changed = _user == null ||
            updatedUser.role != _user!.role ||
            updatedUser.isActive != _user!.isActive ||
            updatedUser.campusId != _user!.campusId ||
            updatedUser.currentStatus != _user!.currentStatus ||
            updatedUser.quickMessage != _user!.quickMessage ||
            updatedUser.availabilityStatus != _user!.availabilityStatus;
        if (changed) {
          if (kDebugMode) {
            debugPrint(
              'userStream: role=${updatedUser.role.name}, '
              'isActive=${updatedUser.isActive} — rebuilding UI',
            );
          }
          _user = updatedUser;
          notifyListeners();
        }
      },
      onError: (e) {
        if (kDebugMode) debugPrint('userStream error: $e');
      },
    );
  }

  void _unsubscribeFromUserDoc() {
    _userDocSubscription?.cancel();
    _userDocSubscription = null;
  }

  Future<void> _checkAuthState() async {
    _isLoading = true;
    notifyListeners();

    try {
      final firebaseUser = _authService.currentUser;
      if (firebaseUser != null) {
        // Add timeout to prevent hanging in release mode
        _user = await _authService.getCurrentUserModel().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            if (kDebugMode) debugPrint('getCurrentUserModel timed out');
            return null;
          },
        );

        // If user document doesn't exist, create one (legacy user migration)
        _user ??= await _authService
            .createUserDocumentForLegacyUser(firebaseUser)
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                if (kDebugMode) {
                  debugPrint('createUserDocumentForLegacyUser timed out');
                }
                return null;
              },
            );

        // Check if user is banned — defer sign out to AuthWrapper (don't sign out during state init)
        if (_user != null && !_user!.isActive) {
          if (kDebugMode) {
            debugPrint('User is inactive — AuthWrapper will handle routing');
          }
        }

        // Start real-time Firestore listener so role/ban changes from
        // the Admin are reflected immediately without a restart.
        if (_user != null) {
          _subscribeToUserDoc(_user!.id);
        }
      }
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) debugPrint('Error checking auth state: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sign in with email and password
  Future<bool> signIn({required String email, required String password}) async {
    _isLoading = true;
    _isSigningIn = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _authService.signInWithEmailPassword(
        email: email,
        password: password,
      );
      _isLoading = false;
      _isSigningIn = false;
      notifyListeners();

      // Persist user ID for push token refresh
      if (_user != null) {
        SharedPreferences.getInstance()
            .then((prefs) {
              prefs.setString('current_user_id', _user!.id);
            })
            .catchError((_) {});
      }

      // Save FCM token for push notifications
      if (_user != null) {
        try {
          PushNotificationService().saveTokenForUser(_user!.id);
        } catch (_) {}
      }

      // Subscribe to real-time Firestore changes so role promotions and
      // bans from Admin are reflected immediately without a restart.
      if (_user != null) {
        _subscribeToUserDoc(_user!.id);
      }

      // On web, Provider's Consumer rebuild can be dropped on the same
      // microtask as the credential-change notification. Schedule a single
      // microtask re-notification (not multiple timers) as a safety net.
      // Using a Completer-backed condition avoids a redundant rebuild storm.
      if (_user != null && kIsWeb) {
        scheduleMicrotask(() {
          if (_user != null && !_isSigningIn) {
            notifyListeners();
          }
        });
      }

      return _user != null;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      _isSigningIn = false;
      // Don't call notifyListeners() here yet — the caller needs to
      // show the error snackbar first. If we notify now, AuthWrapper
      // rebuilds and replaces LoginScreen, making mounted=false
      // before the snackbar can be shown.
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
    String? organization,
    String campusId = 'isulan', // Default campus
  }) async {
    _isLoading = true;
    _isSigningIn = true;
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
        organization: organization,
        campusId: campusId,
      );
      _isLoading = false;
      _isSigningIn = false;
      notifyListeners();

      // Persist user ID for push token refresh
      if (_user != null) {
        SharedPreferences.getInstance()
            .then((prefs) {
              prefs.setString('current_user_id', _user!.id);
            })
            .catchError((_) {});
      }

      // Save FCM token for push notifications
      if (_user != null) {
        try {
          PushNotificationService().saveTokenForUser(_user!.id);
        } catch (_) {}
      }

      // Same single-microtask safety net as signIn for web
      if (_user != null && kIsWeb) {
        scheduleMicrotask(() {
          if (_user != null && !_isSigningIn) {
            notifyListeners();
          }
        });
      }

      return _user != null;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      _isSigningIn = false;
      // Defer notify — caller shows error snackbar first
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
    _unsubscribeFromUserDoc(); // Cancel real-time listener before signing out
    await _locationProvider?.stopTracking();
    // Remove FCM token before signing out
    if (_user != null) {
      try {
        await PushNotificationService().removeTokenForUser(_user!.id);
      } catch (_) {}
    }
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
      // Note: sign out for banned users is handled by AuthWrapper, not here
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    _userDocSubscription?.cancel();
    super.dispose();
  }
}
