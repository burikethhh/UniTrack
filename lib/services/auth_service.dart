import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

/// Authentication Service for ISKSULARS TRACK
class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  /// Default constructor - uses Firebase instances
  AuthService()
    : _auth = FirebaseAuth.instance,
      _firestore = FirebaseFirestore.instance;

  /// Testable constructor - allows dependency injection
  @visibleForTesting
  AuthService.testable({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  }) : _auth = auth,
       _firestore = firestore;

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
    // Ensure App Check token is available (required when App Check is registered)
    try {
      final appCheckToken = await FirebaseAppCheck.instance.getToken();
      if (kDebugMode) {
        debugPrint('🔐 App Check token before sign-in: ${appCheckToken != null ? 'present' : 'null'}');
      }
      if (appCheckToken == null && !kDebugMode) {
        throw 'Security verification failed. Please refresh the page and try again.';
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ App Check token check failed: $e');
      if (!kDebugMode) rethrow;
    }

    try {
      if (kDebugMode) debugPrint('Attempting login for: $email');
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (kDebugMode) {
        debugPrint('Firebase Auth successful: uid=${credential.user?.uid}');
      }

      if (credential.user != null) {
        final firebaseUser = credential.user!;

        // Fetch user document — single attempt with reasonable timeout
        // (no retry, retry doubles the wait to 30s+ for no benefit on Spark)
        UserModel? userModel;
        try {
          if (kDebugMode) {
            debugPrint('📖 Fetching user doc for uid: ${firebaseUser.uid}');
          }
          final getUserFuture = getUserById(firebaseUser.uid);
          if (kDebugMode) {
            debugPrint('📖 getUserById Future created, awaiting...');
          }
          userModel = await getUserFuture.timeout(
            kIsWeb ? const Duration(seconds: 15) : const Duration(seconds: 5),
          );
          if (kDebugMode) {
            debugPrint(
              '✅ User doc fetched: ${userModel != null ? userModel.fullName : "null"}',
            );
          }
        } catch (e) {
          if (kDebugMode) debugPrint('Error fetching user document: $e');
        }

        if (userModel == null) {
          await _auth.signOut();
          throw 'Could not load your profile. Please check your connection and try again.';
        }

        // Check if user is banned / pending approval
        if (!userModel.isActive) {
          if (kDebugMode) debugPrint('User is banned/inactive');
          await _auth.signOut();
          final isStaffRole =
              userModel.role == UserRole.studentLeader ||
              userModel.role == UserRole.organizationOfficer;
          throw isStaffRole
              ? 'Your account is pending admin approval. You\'ll be able to log in once approved.'
              : 'Your account has been disabled. Please contact an administrator.';
        }

        // Enforce email verification for non-admin users
        // Admins are exempt (may be seeded without a verified email)
        if (!firebaseUser.emailVerified && userModel.role != UserRole.admin) {
          if (kDebugMode) debugPrint('Email not verified — blocking login');
          await _auth.signOut();
          throw 'Please verify your email before logging in. '
              'Check your inbox for the verification link, or use the "Resend verification" option on the login screen.';
        }

        // Update last login time in background (fire-and-forget, don't block)
        _firestore
            .collection('users')
            .doc(firebaseUser.uid)
            .set({'lastLoginAt': Timestamp.now()}, SetOptions(merge: true))
            .catchError((e) {
              if (kDebugMode) debugPrint('Error updating last login: $e');
            });

        if (kDebugMode) {
          debugPrint('Login successful for: ${userModel.fullName}');
        }
        return userModel;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        debugPrint('FirebaseAuthException: ${e.code} - ${e.message}');
      }
      throw _handleAuthException(e);
    } catch (e) {
      if (kDebugMode) debugPrint('Unexpected login error: $e');
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
    String? organization,
    String campusId = 'isulan', // Default to Isulan campus
  }) async {
    // Enforce SKSU email domain
    if (!email.toLowerCase().endsWith('@sksu.edu.ph')) {
      throw 'Only SKSU email addresses (@sksu.edu.ph) are allowed to register.';
    }

    // Ensure App Check token is available (required when App Check is registered)
    try {
      final appCheckToken = await FirebaseAppCheck.instance.getToken();
      if (kDebugMode) {
        debugPrint('🔐 App Check token before registration: ${appCheckToken != null ? 'present' : 'null'}');
      }
      if (appCheckToken == null && !kDebugMode) {
        // In production, require a valid token
        throw 'Security verification failed. Please refresh the page and try again.';
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ App Check token check failed: $e');
      // Don't block registration in debug mode — allow fallback
      if (!kDebugMode) rethrow;
    }

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        final isStaffRole =
            role == UserRole.studentLeader ||
            role == UserRole.organizationOfficer;

        final user = UserModel(
          id: credential.user!.uid,
          email: email,
          firstName: firstName,
          lastName: lastName,
          role: role,
          department: department,
          position: position,
          organization: organization,
          campusId: campusId,
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
          isTrackingEnabled: false,
          isActive: !isStaffRole,
          currentStatus: isStaffRole ? 'Available' : null,
          availabilityStatus: isStaffRole ? AvailabilityStatus.available : null,
          statusUpdatedAt: isStaffRole ? DateTime.now() : null,
          statusExpiresAt: isStaffRole
              ? DateTime.now().add(const Duration(hours: 8))
              : null,
        );

        // Write user document to Firestore first — if this fails (e.g. rules, timeout),
        // roll back the Auth account so the user can retry registration cleanly.
        try {
          if (kDebugMode) {
            debugPrint(
              '📝 Starting Firestore write for uid: ${credential.user!.uid}',
            );
          }
          if (kDebugMode) {
            debugPrint(
              '📝 Data to write: ${user.toFirestore(includeDeleteSentinels: false).keys.toList()}',
            );
          }
          final writeFuture = _firestore
              .collection('users')
              .doc(credential.user!.uid)
              .set(user.toFirestore(includeDeleteSentinels: false));
          if (kDebugMode) debugPrint('📝 Write Future created, awaiting...');

          await writeFuture.timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw Exception('Firestore write timed out after 15 seconds');
            },
          );
          if (kDebugMode) {
            debugPrint('✅ Firestore write completed successfully');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('❌ Firestore write failed during registration: $e');
          }
          if (kDebugMode) debugPrint('❌ Error type: ${e.runtimeType}');
          // Roll back the Auth account to avoid an orphaned login
          try {
            await credential.user!.delete();
            if (kDebugMode) {
              debugPrint('✅ Auth account rolled back successfully');
            }
          } catch (deleteErr) {
            if (kDebugMode) {
              debugPrint('⚠️ Could not roll back Auth account: $deleteErr');
            }
          }
          throw 'Registration failed: your profile could not be created. '
              'This may be due to a network or permissions issue — please contact an administrator. '
              '(Detail: $e)';
        }

        // Send email verification (best-effort, don't block registration)
        try {
          await credential.user!.sendEmailVerification(
            ActionCodeSettings(
              url: 'https://isksulars-track.web.app/__/auth/action',
              handleCodeInApp: false,
            ),
          );
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ Could not send verification email: $e');
          }
        }

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
      if (kDebugMode) {
        debugPrint(
          '🔍 getUserById: calling _firestore.collection("users").doc("$userId").get()',
        );
      }
      final doc = await _firestore.collection('users').doc(userId).get();
      if (kDebugMode) debugPrint('🔍 getUserById: doc exists = ${doc.exists}');
      if (doc.exists) {
        try {
          return UserModel.fromFirestore(doc);
        } catch (e) {
          // If parsing fails, try to migrate the document
          if (kDebugMode) {
            debugPrint('Error parsing user document, attempting migration: $e');
          }
          return await migrateUserDocument(userId);
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching user: $e');
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
      final existingDoc = await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .get();
      if (existingDoc.exists) {
        // Document exists, return it as UserModel
        return UserModel.fromFirestore(existingDoc);
      }

      // Create new user document from Firebase Auth data
      final email = firebaseUser.email ?? '';
      final nameParts = (firebaseUser.displayName ?? email.split('@').first)
          .split(' ');
      final firstName = nameParts.isNotEmpty ? nameParts.first : 'User';
      final lastName = nameParts.length > 1
          ? nameParts.sublist(1).join(' ')
          : '';

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
          .set(user.toFirestore(includeDeleteSentinels: false));

      if (kDebugMode) {
        debugPrint(
          'Created user document for legacy user: ${firebaseUser.uid}',
        );
      }
      return user;
    } catch (e) {
      if (kDebugMode) debugPrint('Error creating legacy user document: $e');
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
        await _firestore
            .collection('users')
            .doc(userId)
            .set(updates, SetOptions(merge: true));
        if (kDebugMode) {
          debugPrint(
            'Migrated user document $userId with fields: ${updates.keys.join(', ')}',
          );
        }
      }

      // Re-fetch and parse — don't recurse through getUserById
      final updatedDoc = await _firestore.collection('users').doc(userId).get();
      if (updatedDoc.exists) {
        return UserModel.fromFirestore(updatedDoc);
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('Error migrating user document: $e');
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
  /// Resend verification email — signs in briefly, sends, then signs out.
  /// Used from login screen's "Resend verification" dialog.
  Future<void> resendVerificationEmail({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = cred.user;
      if (user == null) throw 'Could not sign in.';
      if (user.emailVerified) {
        await _auth.signOut();
        throw 'Your email is already verified. You can log in now.';
      }
      // Check if user is banned — don't allow banned users to get tokens
      bool isBanned = false;
      try {
        final userDoc = await getUserById(user.uid);
        if (userDoc != null && !userDoc.isActive) {
          isBanned = true;
        }
      } catch (_) {}
      if (isBanned) {
        await _auth.signOut();
        throw 'Your account has been disabled. Please contact an administrator.';
      }
      await user.sendEmailVerification(
        ActionCodeSettings(
          url: 'https://isksulars-track.web.app/__/auth/action',
          handleCodeInApp: false,
        ),
      );
      await _auth.signOut();
    } catch (e) {
      try {
        await _auth.signOut();
      } catch (_) {}
      rethrow;
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      if (kDebugMode) debugPrint('🔑 Sending password reset email to: $email');
      await _auth.sendPasswordResetEmail(email: email);
      if (kDebugMode) {
        debugPrint('✅ Password reset email sent successfully to: $email');
      }
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '❌ Password reset error: code=${e.code}, message=${e.message}',
        );
      }
      throw _handleAuthException(e);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Password reset unexpected error: $e');
      rethrow;
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
      // Clean up Firestore data while the user's auth token is still valid.
      try {
        await _firestore.collection('locations').doc(userId).delete();
      } catch (_) {}

      // Delete user's notifications (both sent and received) in chunks
      try {
        final receivedSnap = await _firestore
            .collection('notifications')
            .where('recipientId', isEqualTo: userId)
            .get();
        final sentSnap = await _firestore
            .collection('notifications')
            .where('senderId', isEqualTo: userId)
            .get();
        final allDocs = [...receivedSnap.docs, ...sentSnap.docs];
        for (int i = 0; i < allDocs.length; i += 499) {
          final batch = _firestore.batch();
          final end = (i + 499 < allDocs.length) ? i + 499 : allDocs.length;
          for (final doc in allDocs.sublist(i, end)) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        }
      } catch (_) {}

      await _firestore.collection('users').doc(userId).delete();

      // Delete the Firebase Auth account last. If recent login is required,
      // the profile remains intact and the user can retry safely.
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
    if (kDebugMode) {
      debugPrint('Firebase Auth Error: code=${e.code}, message=${e.message}');
    }
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
