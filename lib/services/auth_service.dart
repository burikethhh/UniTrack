import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  
  /// Sign in with email and password
  Future<UserModel?> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (credential.user != null) {
        // Fetch user model first to check if banned
        final userModel = await getUserById(credential.user!.uid);
        
        // Check if user is banned
        if (userModel != null && !userModel.isActive) {
          // Sign out the banned user
          await _auth.signOut();
          throw 'Your account has been disabled. Please contact an administrator.';
        }
        
        // Update last login time
        await _firestore.collection('users').doc(credential.user!.uid).update({
          'lastLoginAt': Timestamp.now(),
        });
        
        // Return updated user model
        return await getUserById(credential.user!.uid);
      }
      return null;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
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
  
  /// Get user by ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw 'Error fetching user: $e';
    }
  }
  
  /// Get current user model
  Future<UserModel?> getCurrentUserModel() async {
    if (currentUser == null) return null;
    return await getUserById(currentUser!.uid);
  }
  
  /// Update user profile
  Future<void> updateUserProfile(UserModel user) async {
    try {
      await _firestore
          .collection('users')
          .doc(user.id)
          .update(user.toFirestore());
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
  
  /// Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return e.message ?? 'An authentication error occurred.';
    }
  }
}
