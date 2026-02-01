import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart' as open_file;
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
      debugPrint('🔍 Checking for updates (current: v$currentVersionName, code: $currentVersionCode)');
      
      // Get latest active version
      final snapshot = await _firestore
          .collection('app_versions')
          .where('isActive', isEqualTo: true)
          .orderBy('versionCode', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        debugPrint('📭 No versions found in database');
        return UpdateCheckResult(
          updateAvailable: false,
          message: 'No updates available',
        );
      }

      final latestVersion = AppVersion.fromFirestore(snapshot.docs.first);
      debugPrint('📦 Latest version: v${latestVersion.versionName} (code: ${latestVersion.versionCode})');

      if (latestVersion.isNewerThan(currentVersionCode)) {
        debugPrint('✨ Update available!');
        return UpdateCheckResult(
          updateAvailable: true,
          isRequired: latestVersion.isRequired,
          latestVersion: latestVersion,
          message: latestVersion.isRequired
              ? 'A required update is available'
              : 'A new version is available',
        );
      }

      debugPrint('✅ App is up to date');
      return UpdateCheckResult(
        updateAvailable: false,
        message: 'You have the latest version',
      );
    } catch (e) {
      debugPrint('❌ Error checking for updates: $e');
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
      debugPrint('Error checking version support: $e');
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
      debugPrint('Error getting version: $e');
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
      debugPrint('Error getting versions: $e');
      return [];
    }
  }

  /// Download and install update
  /// Supports both Firebase Storage URLs and GitHub/HTTP URLs
  Future<bool> downloadAndInstallUpdate(
    AppVersion version, {
    Function(double)? onProgress,
  }) async {
    try {
      // Request storage permission
      if (Platform.isAndroid) {
        final status = await Permission.requestInstallPackages.request();
        if (!status.isGranted) {
          debugPrint('Install packages permission denied');
          return false;
        }
      }

      // Get download directory
      final dir = await getExternalStorageDirectory();
      if (dir == null) {
        debugPrint('Could not get storage directory');
        return false;
      }

      final filePath = '${dir.path}/UniTrack_${version.versionName}.apk';
      final file = File(filePath);

      // Check if already downloaded
      if (await file.exists()) {
        debugPrint('APK already exists, opening installer');
        return await _installApk(filePath);
      }

      debugPrint('📥 Downloading APK from: ${version.downloadUrl}');
      
      // Check if URL is Firebase Storage or HTTP (GitHub)
      if (version.downloadUrl.contains('firebasestorage.googleapis.com')) {
        // Firebase Storage download
        final ref = _storage.refFromURL(version.downloadUrl);
        final downloadTask = ref.writeToFile(file);

        downloadTask.snapshotEvents.listen((event) {
          final progress = event.bytesTransferred / event.totalBytes;
          onProgress?.call(progress);
          debugPrint('📥 Download progress: ${(progress * 100).toStringAsFixed(1)}%');
        });

        await downloadTask;
      } else {
        // HTTP download (GitHub, etc.)
        try {
          await _downloadFromHttp(version.downloadUrl, file, onProgress);
        } catch (e) {
          debugPrint('❌ HTTP download failed: $e');
          // Clean up partial file
          if (await file.exists()) {
            await file.delete();
          }
          rethrow;
        }
      }
      
      // Verify file was downloaded
      if (!await file.exists()) {
        debugPrint('❌ Downloaded file does not exist');
        return false;
      }
      
      final fileSize = await file.length();
      debugPrint('✅ APK downloaded: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
      
      if (fileSize < 1024 * 1024) { // Less than 1MB is likely an error
        debugPrint('❌ Downloaded file too small, likely an error page');
        await file.delete();
        return false;
      }

      // Increment download count
      await _incrementDownloadCount(version.id);

      // Install APK
      return await _installApk(filePath);
    } catch (e) {
      debugPrint('❌ Error downloading update: $e');
      return false;
    }
  }

  /// Download file from HTTP URL with progress tracking
  /// Handles redirects for GitHub releases
  Future<void> _downloadFromHttp(
    String url,
    File file,
    Function(double)? onProgress,
  ) async {
    debugPrint('📥 Starting HTTP download from: $url');
    
    // Create HTTP client that follows redirects
    final client = http.Client();
    
    try {
      // For GitHub releases, we need to follow redirects
      // First, get the final URL after redirects
      var currentUrl = url;
      http.StreamedResponse? response;
      int maxRedirects = 5;
      
      for (int i = 0; i < maxRedirects; i++) {
        final request = http.Request('GET', Uri.parse(currentUrl));
        request.followRedirects = false; // Handle manually to track
        
        response = await client.send(request);
        
        if (response.statusCode >= 300 && response.statusCode < 400) {
          // It's a redirect
          final location = response.headers['location'];
          if (location != null) {
            debugPrint('↪️ Redirect $i: $location');
            currentUrl = location;
            await response.stream.drain(); // Consume the redirect response
            continue;
          }
        }
        break; // Not a redirect, proceed with download
      }
      
      if (response == null || response.statusCode != 200) {
        throw Exception('Download failed with status: ${response?.statusCode}');
      }
      
      final contentLength = response.contentLength ?? 0;
      debugPrint('📦 Content length: ${(contentLength / 1024 / 1024).toStringAsFixed(2)} MB');
      
      int downloadedBytes = 0;
      final sink = file.openWrite();
      
      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;
        if (contentLength > 0) {
          final progress = downloadedBytes / contentLength;
          onProgress?.call(progress);
          if (downloadedBytes % (1024 * 1024) < chunk.length) {
            // Log every ~1MB
            debugPrint('📥 Download: ${(progress * 100).toStringAsFixed(1)}%');
          }
        }
      }
      
      await sink.close();
      debugPrint('✅ Download complete: ${file.path} (${(downloadedBytes / 1024 / 1024).toStringAsFixed(2)} MB)');
    } finally {
      client.close();
    }
  }

  /// Install APK file
  Future<bool> _installApk(String filePath) async {
    try {
      final result = await open_file.OpenFile.open(filePath);
      return result.type == open_file.ResultType.done;
    } catch (e) {
      debugPrint('Error installing APK: $e');
      return false;
    }
  }

  /// Increment download count
  Future<void> _incrementDownloadCount(String versionId) async {
    try {
      await _firestore.collection('app_versions').doc(versionId).update({
        'downloadCount': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('Error incrementing download count: $e');
    }
  }

  /// Upload new version (Admin only)
  Future<AppVersion?> uploadNewVersion({
    required String versionName,
    required int versionCode,
    required File apkFile,
    String? releaseNotes,
    bool isRequired = false,
    Function(double)? onProgress,
  }) async {
    try {
      // Upload to Firebase Storage
      final fileName = 'UniTrack_v$versionName.apk';
      final ref = _storage.ref('apk_releases/$fileName');
      
      final uploadTask = ref.putFile(
        apkFile,
        SettableMetadata(contentType: 'application/vnd.android.package-archive'),
      );

      // Track progress
      uploadTask.snapshotEvents.listen((event) {
        final progress = event.bytesTransferred / event.totalBytes;
        onProgress?.call(progress);
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      final fileSize = await apkFile.length();

      // Create version document
      final version = AppVersion(
        id: '',
        versionName: versionName,
        versionCode: versionCode,
        downloadUrl: downloadUrl,
        releaseNotes: releaseNotes,
        isRequired: isRequired,
        isActive: true,
        releaseDate: DateTime.now(),
        fileSize: fileSize,
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
      debugPrint('Error uploading version: $e');
      return null;
    }
  }

  /// Toggle version active status
  Future<bool> toggleVersionActive(String versionId, bool isActive) async {
    try {
      await _firestore.collection('app_versions').doc(versionId).update({
        'isActive': isActive,
      });
      return true;
    } catch (e) {
      debugPrint('Error toggling version: $e');
      return false;
    }
  }

  /// Set version as required update
  Future<bool> setVersionRequired(String versionId, bool isRequired) async {
    try {
      await _firestore.collection('app_versions').doc(versionId).update({
        'isRequired': isRequired,
      });
      return true;
    } catch (e) {
      debugPrint('Error setting required: $e');
      return false;
    }
  }

  /// Delete version (removes from Firestore but keeps file in Storage)
  Future<bool> deleteVersion(String versionId) async {
    try {
      await _firestore.collection('app_versions').doc(versionId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting version: $e');
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

      // Create notification for each user
      final batch = _firestore.batch();
      
      for (final userDoc in usersSnapshot.docs) {
        final notifRef = _firestore.collection('notifications').doc();
        batch.set(notifRef, {
          'recipientId': userDoc.id,
          'title': title,
          'body': message,
          'type': 'app_update',
          'data': {'versionName': versionName},
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      debugPrint('Sent update notification to ${usersSnapshot.docs.length} users');
      return true;
    } catch (e) {
      debugPrint('Error sending update notification: $e');
      return false;
    }
  }
}
