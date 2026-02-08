import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

/// Authentication Service for UniTrack
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Get current Firebase user
  User? get currentUser => _auth.currentUser;
  
  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  /// Check if user is logged in
  bool get isLoggedIn => currentUser != null;
  
  /// Build a fallback UserModel from Firebase Auth data when Firestore is unavailable
  UserModel _buildFallbackUser(User firebaseUser, String email) {
    final nameParts = (firebaseUser.displayName ?? email.split('@').first).split(' ');
    final firstName = nameParts.isNotEmpty ? nameParts.first : 'User';
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
    return UserModel(
      id: firebaseUser.uid,
      email: email,
      firstName: firstName,
      lastName: lastName,
      role: UserRole.student,
      createdAt: firebaseUser.metadata.creationTime ?? DateTime.now(),
      lastLoginAt: DateTime.now(),
      campusId: 'isulan',
      isActive: true,
    );
  }

  /// Sign in with email and password
  Future<UserModel?> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('Attempting login for: $email');
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      debugPrint('Firebase Auth successful: uid=${credential.user?.uid}');
      
      if (credential.user != null) {
        final firebaseUser = credential.user!;
        
        // Fetch user model with timeout to prevent hanging
        UserModel? userModel;
        try {
          userModel = await getUserById(firebaseUser.uid).timeout(
            const Duration(seconds: 8),
            onTimeout: () {
              debugPrint('getUserById timed out, using fallback');
              return null;
            },
          );
          debugPrint('User document found: ${userModel?.fullName}');
        } catch (e) {
          debugPrint('Error fetching user document: $e');
        }
        
        // If user document doesn't exist or Firestore timed out, build from Auth data
        if (userModel == null) {
          debugPrint('No user document found or timed out, creating fallback...');
          userModel = _buildFallbackUser(firebaseUser, email);
          
          // Try to save the document in the background (don't await/block)
          _firestore
              .collection('users')
              .doc(firebaseUser.uid)
              .set(userModel.toFirestore(), SetOptions(merge: true))
              .then((_) => debugPrint('Created/merged user document for: ${firebaseUser.uid}'))
              .catchError((e) => debugPrint('Error saving user document: $e'));
          
          return userModel;
        }
        
        // Check if user is banned
        if (!userModel.isActive) {
          debugPrint('User is banned/inactive');
          await _auth.signOut();
          throw 'Your account has been disabled. Please contact an administrator.';
        }
        
        // Update last login time in background (fire-and-forget, don't block)
        _firestore.collection('users').doc(firebaseUser.uid).set({
          'lastLoginAt': Timestamp.now(),
        }, SetOptions(merge: true)).catchError((e) {
          debugPrint('Error updating last login: $e');
        });
        
        debugPrint('Login successful for: ${userModel.fullName}');
        return userModel;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('Unexpected login error: $e');
      rethrow;
    }
  }
  
  /// Register new user with email and password
  Future<UserModel?> registerWithEmailPassword({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required UserRole role,
    String? department,
    String? position,
    String campusId = 'isulan', // Default to Isulan campus
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (credential.user != null) {
        final user = UserModel(
          id: credential.user!.uid,
          email: email,
          firstName: firstName,
          lastName: lastName,
          role: role,
          department: department,
          position: position,
          campusId: campusId,
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
          isTrackingEnabled: false,
          currentStatus: role == UserRole.staff ? 'Available' : null,
        );
        
        // Save user to Firestore
        await _firestore
            .collection('users')
            .doc(credential.user!.uid)
            .set(user.toFirestore());
        
        return user;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }
  
  /// Get user by ID (with automatic migration for old documents)
  Future<UserModel?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        try {
          return UserModel.fromFirestore(doc);
        } catch (e) {
          // If parsing fails, try to migrate the document
          debugPrint('Error parsing user document, attempting migration: $e');
          return await migrateUserDocument(userId);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching user: $e');
      throw 'Error fetching user: $e';
    }
  }
  
  /// Get current user model
  Future<UserModel?> getCurrentUserModel() async {
    if (currentUser == null) return null;
    return await getUserById(currentUser!.uid);
  }
  
  /// Create user document for legacy/migrated users who have Firebase Auth but no Firestore document
  Future<UserModel?> createUserDocumentForLegacyUser(User firebaseUser) async {
    try {
      // Check if document already exists
      final existingDoc = await _firestore.collection('users').doc(firebaseUser.uid).get();
      if (existingDoc.exists) {
        // Document exists, return it as UserModel
        return UserModel.fromFirestore(existingDoc);
      }
      
      // Create new user document from Firebase Auth data
      final email = firebaseUser.email ?? '';
      final nameParts = (firebaseUser.displayName ?? email.split('@').first).split(' ');
      final firstName = nameParts.isNotEmpty ? nameParts.first : 'User';
      final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
      
      final user = UserModel(
        id: firebaseUser.uid,
        email: email,
        firstName: firstName,
        lastName: lastName,
        role: UserRole.student, // Default to student for legacy users
        createdAt: firebaseUser.metadata.creationTime ?? DateTime.now(),
        lastLoginAt: DateTime.now(),
        campusId: 'isulan', // Default campus
        isActive: true,
      );
      
      // Save to Firestore
      await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .set(user.toFirestore());
      
      debugPrint('Created user document for legacy user: ${firebaseUser.uid}');
      return user;
    } catch (e) {
      debugPrint('Error creating legacy user document: $e');
      return null;
    }
  }
  
  /// Migrate user document to ensure all required fields exist
  Future<UserModel?> migrateUserDocument(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      
      final data = doc.data() as Map<String, dynamic>;
      final updates = <String, dynamic>{};
      
      // Add missing fields with defaults
      if (data['campusId'] == null) {
        updates['campusId'] = 'isulan';
      }
      if (data['isActive'] == null) {
        updates['isActive'] = true;
      }
      if (data['createdAt'] == null) {
        updates['createdAt'] = Timestamp.now();
      }
      if (data['firstName'] == null || (data['firstName'] as String).isEmpty) {
        final email = (data['email'] as String?) ?? '';
        updates['firstName'] = email.split('@').first;
      }
      if (data['lastName'] == null) {
        updates['lastName'] = '';
      }
      if (data['role'] == null) {
        updates['role'] = 'student';
      }
      
      // Apply updates if any
      if (updates.isNotEmpty) {
        await _firestore.collection('users').doc(userId).set(updates, SetOptions(merge: true));
        debugPrint('Migrated user document $userId with fields: ${updates.keys.join(', ')}');
      }
      
      // Return updated user
      return await getUserById(userId);
    } catch (e) {
      debugPrint('Error migrating user document: $e');
      return null;
    }
  }

  /// Update user profile
  Future<void> updateUserProfile(UserModel user) async {
    try {
      await _firestore
          .collection('users')
          .doc(user.id)
          .set(user.toFirestore(), SetOptions(merge: true));
    } catch (e) {
      throw 'Error updating profile: $e';
    }
  }
  
  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }
  
  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Re-authenticate user before sensitive operations
  Future<void> reauthenticate(String email, String password) async {
    final user = _auth.currentUser;
    if (user == null) throw 'No user is currently signed in.';
    
    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
  }

  /// Delete user account and all associated data
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw 'No user is currently signed in.';
    
    final userId = user.uid;
    
    try {
      // Delete user's location data
      try {
        await _firestore.collection('locations').doc(userId).delete();
      } catch (_) {}
      
      // Delete user's notifications
      try {
        final notifSnap = await _firestore
            .collection('notifications')
            .where('userId', isEqualTo: userId)
            .get();
        for (final doc in notifSnap.docs) {
          await doc.reference.delete();
        }
      } catch (_) {}
      
      // Delete user document from Firestore
      await _firestore.collection('users').doc(userId).delete();
      
      // Delete the Firebase Auth account
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw 'requires-recent-login';
      }
      throw _handleAuthException(e);
    }
  }
  
  /// Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    debugPrint('Firebase Auth Error: code=${e.code}, message=${e.message}');
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-credential':
        // This is the new error code for wrong password or user not found
        return 'Invalid email or password. Please check your credentials.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'Email/password sign in is not enabled.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Invalid email or password. Please check your credentials.';
      default:
        return e.message ?? 'An authentication error occurred.';
    }
  }
}
