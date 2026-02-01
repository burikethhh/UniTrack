import 'package:cloud_firestore/cloud_firestore.dart';

/// App version model for tracking releases
/// Supports backwards compatibility with older app versions
class AppVersion {
  final String id;
  final String versionName;      // e.g., "1.2.0"
  final int versionCode;         // e.g., 120
  final String downloadUrl;      // Firebase Storage URL
  final String? releaseNotes;
  final bool isRequired;         // Force update if true
  final bool isActive;           // Is this version available
  final DateTime releaseDate;
  final int downloadCount;
  final int fileSize;            // In bytes
  final int minSupportedApiVersion; // Minimum API version this release supports

  AppVersion({
    required this.id,
    required this.versionName,
    required this.versionCode,
    required this.downloadUrl,
    this.releaseNotes,
    this.isRequired = false,
    this.isActive = true,
    required this.releaseDate,
    this.downloadCount = 0,
    this.fileSize = 0,
    this.minSupportedApiVersion = 1,
  });

  factory AppVersion.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppVersion(
      id: doc.id,
      versionName: data['versionName'] ?? '1.0.0',
      versionCode: data['versionCode'] ?? 1,
      downloadUrl: data['downloadUrl'] ?? '',
      releaseNotes: data['releaseNotes'],
      isRequired: data['isRequired'] ?? false,
      isActive: data['isActive'] ?? true,
      releaseDate: (data['releaseDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      downloadCount: data['downloadCount'] ?? 0,
      fileSize: data['fileSize'] ?? 0,
      minSupportedApiVersion: data['minSupportedApiVersion'] ?? 1,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'versionName': versionName,
      'versionCode': versionCode,
      'downloadUrl': downloadUrl,
      'releaseNotes': releaseNotes,
      'isRequired': isRequired,
      'isActive': isActive,
      'releaseDate': Timestamp.fromDate(releaseDate),
      'downloadCount': downloadCount,
      'fileSize': fileSize,
      'minSupportedApiVersion': minSupportedApiVersion,
    };
  }

  /// Compare versions
  bool isNewerThan(int currentVersionCode) {
    return versionCode > currentVersionCode;
  }

  /// Format file size
  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Update check result
class UpdateCheckResult {
  final bool updateAvailable;
  final bool isRequired;
  final AppVersion? latestVersion;
  final String? message;

  UpdateCheckResult({
    required this.updateAvailable,
    this.isRequired = false,
    this.latestVersion,
    this.message,
  });

  /// Alias for updateAvailable to match common naming
  bool get hasUpdate => updateAvailable;
}
