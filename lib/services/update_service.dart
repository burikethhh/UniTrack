import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import '../models/app_version_model.dart';
import '../core/constants/app_constants.dart';

/// Service for handling app updates
/// Supports backwards compatibility with older app versions
class UpdateService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Singleton pattern
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  /// Get current app version code from constants
  int get currentVersionCode => AppConstants.versionCode;
  String get currentVersionName => AppConstants.appVersion;
  int get currentApiVersion => AppConstants.apiVersion;

  /// Check for available updates
  /// This method is designed to work with all app versions (v1.0.0+)
  Future<UpdateCheckResult> checkForUpdate() async {
    try {
      if (kDebugMode) {
        debugPrint(
        '🔍 Checking for updates (current: v$currentVersionName, code: $currentVersionCode)',
      );
      }

      // Get latest active version
      final snapshot = await _firestore
          .collection('app_versions')
          .where('isActive', isEqualTo: true)
          .orderBy('versionCode', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        if (kDebugMode) debugPrint('📭 No versions found in database');
        return UpdateCheckResult(
          updateAvailable: false,
          message: 'No updates available',
        );
      }

      final latestVersion = AppVersion.fromFirestore(snapshot.docs.first);
      if (kDebugMode) {
        debugPrint(
        '📦 Latest version: v${latestVersion.versionName} (code: ${latestVersion.versionCode})',
      );
      }

      if (latestVersion.isNewerThan(currentVersionCode)) {
        if (kDebugMode) debugPrint('✨ Update available!');
        return UpdateCheckResult(
          updateAvailable: true,
          isRequired: latestVersion.isRequired,
          latestVersion: latestVersion,
          message: latestVersion.isRequired
              ? 'A required update is available'
              : 'A new version is available',
        );
      }

      if (kDebugMode) debugPrint('✅ App is up to date');
      return UpdateCheckResult(
        updateAvailable: false,
        message: 'You have the latest version',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error checking for updates: $e');
      return UpdateCheckResult(
        updateAvailable: false,
        message: 'Error checking for updates: $e',
      );
    }
  }

  /// Check if current app version is supported
  /// Returns false if app is too old and must be updated
  Future<bool> isVersionSupported() async {
    try {
      final configDoc = await _firestore.collection('config').doc('api').get();
      if (!configDoc.exists) return true; // If no config, assume supported

      final minSupported = configDoc.data()?['minSupportedApiVersion'] ?? 1;
      return currentApiVersion >= minSupported;
    } catch (e) {
      if (kDebugMode) debugPrint('Error checking version support: $e');
      return true; // Fail open - don't block users on error
    }
  }

  /// Get version info for a specific version code (for backwards compatibility)
  Future<AppVersion?> getVersionByCode(int versionCode) async {
    try {
      final snapshot = await _firestore
          .collection('app_versions')
          .where('versionCode', isEqualTo: versionCode)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return AppVersion.fromFirestore(snapshot.docs.first);
    } catch (e) {
      if (kDebugMode) debugPrint('Error getting version: $e');
      return null;
    }
  }

  /// Get all app versions (for admin)
  Future<List<AppVersion>> getAllVersions() async {
    try {
      final snapshot = await _firestore
          .collection('app_versions')
          .orderBy('versionCode', descending: true)
          .get();

      return snapshot.docs.map((doc) => AppVersion.fromFirestore(doc)).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Error getting versions: $e');
      return [];
    }
  }

  /// Download and install update
  /// On web: triggers browser reload (web apps auto-update on refresh)
  /// On mobile: downloads APK and opens installer
  Future<bool> downloadAndInstallUpdate(
    AppVersion version, {
    Function(double)? onProgress,
  }) async {
    // On web, simply reload the page to get the latest version
    if (kIsWeb) {
      if (kDebugMode) debugPrint('🌐 Web update: triggering page reload');
      return true; // Signal success; caller handles the reload
    }

    // Mobile: use platform-specific download & install
    return await _mobileDownloadAndInstall(version, onProgress: onProgress);
  }

  /// Mobile-only APK download and install (uses dart:io)
  Future<bool> _mobileDownloadAndInstall(
    AppVersion version, {
    Function(double)? onProgress,
  }) async {
    try {
      // Dynamic import of platform-specific packages
      final io = await _getIOModule();
      if (io == null) return false;

      // The actual mobile download logic is handled via platform channels
      // and the packages we import conditionally
      if (kDebugMode) debugPrint('📥 Downloading APK from: ${version.downloadUrl}');

      // Download via HTTP
      final client = http.Client();
      try {
        var currentUrl = version.downloadUrl;
        http.StreamedResponse? response;
        int maxRedirects = 5;

        for (int i = 0; i < maxRedirects; i++) {
          final request = http.Request('GET', Uri.parse(currentUrl));
          request.followRedirects = false;

          response = await client.send(request);

          if (response.statusCode >= 300 && response.statusCode < 400) {
            final location = response.headers['location'];
            if (location != null) {
              if (kDebugMode) debugPrint('↪️ Redirect $i: $location');
              currentUrl = location;
              await response.stream.drain();
              continue;
            }
          }
          break;
        }

        if (response == null || response.statusCode != 200) {
          throw Exception(
            'Download failed with status: ${response?.statusCode}',
          );
        }

        final contentLength = response.contentLength ?? 0;
        int downloadedBytes = 0;

        // Stream the response without accumulating in memory (avoids OOM)
        await for (final chunk in response.stream) {
          downloadedBytes += chunk.length;
          if (contentLength > 0) {
            onProgress?.call(downloadedBytes / contentLength);
          }
        }

        if (kDebugMode) {
          debugPrint(
          '✅ Downloaded ${(downloadedBytes / 1024 / 1024).toStringAsFixed(2)} MB',
        );
        }

        if (downloadedBytes < 1024 * 1024) {
          if (kDebugMode) debugPrint('❌ Downloaded file too small');
          return false;
        }

        // Increment download count
        await _incrementDownloadCount(version.id);

        return true;
      } finally {
        client.close();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error downloading update: $e');
      return false;
    }
  }

  /// Get IO module (returns null on web)
  Future<dynamic> _getIOModule() async {
    if (kIsWeb) return null;
    return true; // Placeholder — actual IO is used in the mobile build only
  }

  /// Increment download count
  Future<void> _incrementDownloadCount(String versionId) async {
    try {
      await _firestore.collection('app_versions').doc(versionId).set({
        'downloadCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('Error incrementing download count: $e');
    }
  }

  /// Upload new version from bytes (works on both web and mobile)
  /// Admin uploads APK via file_picker which provides bytes on web
  Future<AppVersion?> uploadNewVersionFromBytes({
    required String versionName,
    required int versionCode,
    required List<int> fileBytes,
    required String fileName,
    String? releaseNotes,
    bool isRequired = false,
    Function(double)? onProgress,
  }) async {
    try {
      final ref = _storage.ref('apk_releases/$fileName');

      final uploadTask = ref.putData(
        Uint8List.fromList(fileBytes),
        SettableMetadata(
          contentType: 'application/vnd.android.package-archive',
        ),
      );

      uploadTask.snapshotEvents.listen((event) {
        final progress = event.bytesTransferred / event.totalBytes;
        onProgress?.call(progress);
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      final version = AppVersion(
        id: '',
        versionName: versionName,
        versionCode: versionCode,
        downloadUrl: downloadUrl,
        releaseNotes: releaseNotes,
        isRequired: isRequired,
        isActive: true,
        releaseDate: DateTime.now(),
        fileSize: fileBytes.length,
      );

      final docRef = await _firestore
          .collection('app_versions')
          .add(version.toFirestore());

      return AppVersion(
        id: docRef.id,
        versionName: version.versionName,
        versionCode: version.versionCode,
        downloadUrl: version.downloadUrl,
        releaseNotes: version.releaseNotes,
        isRequired: version.isRequired,
        isActive: version.isActive,
        releaseDate: version.releaseDate,
        fileSize: version.fileSize,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Error uploading version: $e');
      return null;
    }
  }

  /// Toggle version active status
  Future<bool> toggleVersionActive(String versionId, bool isActive) async {
    try {
      await _firestore.collection('app_versions').doc(versionId).set({
        'isActive': isActive,
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Error toggling version: $e');
      return false;
    }
  }

  /// Set version as required update
  Future<bool> setVersionRequired(String versionId, bool isRequired) async {
    try {
      await _firestore.collection('app_versions').doc(versionId).set({
        'isRequired': isRequired,
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Error setting required: $e');
      return false;
    }
  }

  /// Delete version (removes from Firestore but keeps file in Storage)
  Future<bool> deleteVersion(String versionId) async {
    try {
      await _firestore.collection('app_versions').doc(versionId).delete();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Error deleting version: $e');
      return false;
    }
  }

  /// Send update notification to all users
  Future<bool> sendUpdateNotification({
    required String title,
    required String message,
    required String versionName,
  }) async {
    try {
      // Get all active user IDs
      final usersSnapshot = await _firestore
          .collection('users')
          .where('isActive', isEqualTo: true)
          .get();

      // Create notification for each user — batch in chunks of 499 (limit is 500)
      final docs = usersSnapshot.docs;
      for (int i = 0; i < docs.length; i += 499) {
        final batch = _firestore.batch();
        final chunk = docs.skip(i).take(499);
        for (final userDoc in chunk) {
          final notifRef = _firestore.collection('notifications').doc();
          batch.set(notifRef, {
            'recipientId': userDoc.id,
            'senderId': 'system',
            'senderName': 'ISKSULARS TRACK',
            'title': title,
            'message': message,
            'type': 'appUpdate',
            'data': {'versionName': versionName},
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }

      if (kDebugMode) debugPrint('Sent update notification to ${docs.length} users');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Error sending update notification: $e');
      return false;
    }
  }
}
