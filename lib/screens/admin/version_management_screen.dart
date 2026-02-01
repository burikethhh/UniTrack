import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/app_version_model.dart';
import '../../services/update_service.dart';
import '../../core/constants/app_constants.dart';

/// Admin screen for managing app versions and updates
class VersionManagementScreen extends StatefulWidget {
  const VersionManagementScreen({super.key});

  @override
  State<VersionManagementScreen> createState() => _VersionManagementScreenState();
}

class _VersionManagementScreenState extends State<VersionManagementScreen> {
  final UpdateService _updateService = UpdateService();
  List<AppVersion> _versions = [];
  bool _isLoading = true;
  bool _isUploading = false;
  double _uploadProgress = 0;

  @override
  void initState() {
    super.initState();
    _loadVersions();
  }

  Future<void> _loadVersions() async {
    setState(() => _isLoading = true);
    final versions = await _updateService.getAllVersions();
    if (mounted) {
      setState(() {
        _versions = versions;
        _isLoading = false;
      });
    }
  }

  /// Seed initial version data for the update system
  Future<void> _seedVersionData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.auto_fix_high, color: Colors.blue),
            SizedBox(width: 8),
            Text('Seed Version Data'),
          ],
        ),
        content: const Text(
          'This will create version records in Firestore to enable in-app updates for older app versions.\n\n'
          'Versions to be created:\n'
          '• v1.0.0 (Initial Release)\n'
          '• v1.1.0 (Bug Fixes)\n'
          '• v1.5.0 (Multi-campus)\n'
          '• v2.0.0 (Current - Required)\n\n'
          'Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Seed Data'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      // Version data with GitHub release URLs
      final versions = [
        {
          'versionName': '1.0.0',
          'versionCode': 100,
          'downloadUrl': '',
          'releaseNotes': 'Initial release of UniTrack.\n- Real-time faculty location tracking\n- Student directory\n- Staff dashboard\n- Admin panel',
          'isRequired': false,
          'isActive': false,
          'releaseDate': Timestamp.fromDate(DateTime(2025, 12, 1)),
          'downloadCount': 0,
          'fileSize': 0,
          'minSupportedApiVersion': 1,
        },
        {
          'versionName': '1.1.0',
          'versionCode': 110,
          'downloadUrl': '',
          'releaseNotes': 'Bug fixes and improvements.\n- Fixed location tracking issues\n- Improved UI responsiveness\n- Better error handling',
          'isRequired': false,
          'isActive': false,
          'releaseDate': Timestamp.fromDate(DateTime(2025, 12, 15)),
          'downloadCount': 0,
          'fileSize': 0,
          'minSupportedApiVersion': 1,
        },
        {
          'versionName': '1.5.0',
          'versionCode': 150,
          'downloadUrl': '',
          'releaseNotes': 'Major update!\n- Multi-campus support (Isulan, Tacurong, ACCESS)\n- Enhanced map features\n- Performance improvements',
          'isRequired': false,
          'isActive': false,
          'releaseDate': Timestamp.fromDate(DateTime(2026, 1, 1)),
          'downloadCount': 0,
          'fileSize': 0,
          'minSupportedApiVersion': 1,
        },
        {
          'versionName': '2.0.0',
          'versionCode': 200,
          'downloadUrl': 'https://github.com/burikethhh/UniTrack/releases/download/v2.0.0/unitrack-latest.apk',
          'releaseNotes': 'UniTrack 2.0 - Complete Overhaul!\n\n✨ New Features:\n- Animated splash screen\n- Enhanced location accuracy\n- Network connectivity monitoring\n- Password strength indicator\n\n🔧 Improvements:\n- Faster faculty refresh\n- Adaptive location tracking\n- Improved UI/UX',
          'isRequired': false,
          'isActive': true,
          'releaseDate': Timestamp.fromDate(DateTime(2026, 2, 1)),
          'downloadCount': 0,
          'fileSize': 98000000,
          'minSupportedApiVersion': 2,
        },
        {
          'versionName': '2.0.1',
          'versionCode': 201,
          'downloadUrl': 'https://github.com/burikethhh/UniTrack/releases/download/v2.0.1/unitrack-v2.0.1.apk',
          'releaseNotes': 'UniTrack 2.0.1 - New Features!\n\n✨ New Features:\n- Offline Mode with SQLite caching\n- Faculty Availability Status (Available, Busy, In Meeting, etc.)\n- Onboarding Tutorial for first-time users\n- Skeleton Loading animations\n- Push Notifications (FCM)\n\n🔧 Improvements:\n- Better user experience\n- Smoother loading states',
          'isRequired': true,
          'isActive': true,
          'releaseDate': Timestamp.fromDate(DateTime(2026, 2, 1)),
          'downloadCount': 0,
          'fileSize': 98000000,
          'minSupportedApiVersion': 2,
        },
      ];

      for (final version in versions) {
        // Check if version already exists
        final existing = await firestore
            .collection('app_versions')
            .where('versionCode', isEqualTo: version['versionCode'])
            .get();

        if (existing.docs.isEmpty) {
          final docRef = firestore.collection('app_versions').doc();
          batch.set(docRef, version);
        }
      }

      // Create API config
      final configRef = firestore.collection('config').doc('api');
      batch.set(configRef, {
        'currentApiVersion': AppConstants.apiVersion,
        'minSupportedApiVersion': AppConstants.minSupportedApiVersion,
        'deprecatedApiVersions': <int>[],
        'features': {
          'multiCampusSupport': true,
          'locationSmoothing': true,
          'connectivityMonitoring': true,
          'passwordStrengthCheck': true,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Version data seeded successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
        _loadVersions();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error seeding data: $e')),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Version Management'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadVersions,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Current Version Info
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: theme.colorScheme.primaryContainer.withAlpha(76),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Current App Version',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            Text(
                              'v${_updateService.currentVersionName} (code: ${_updateService.currentVersionCode}, API: ${AppConstants.apiVersion})',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      // Quick seed button for empty database
                      if (_versions.isEmpty)
                        TextButton.icon(
                          icon: const Icon(Icons.auto_fix_high, size: 18),
                          label: const Text('Seed'),
                          onPressed: _seedVersionData,
                        ),
                    ],
                  ),
                ),

                // Versions List
                Expanded(
                  child: _versions.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadVersions,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _versions.length,
                            itemBuilder: (context, index) {
                              return _VersionCard(
                                version: _versions[index],
                                isLatest: index == 0,
                                onToggleActive: () => _toggleActive(_versions[index]),
                                onToggleRequired: () => _toggleRequired(_versions[index]),
                                onSendNotification: () => _showNotificationDialog(_versions[index]),
                                onDelete: () => _deleteVersion(_versions[index]),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: _isUploading
          ? FloatingActionButton.extended(
              onPressed: null,
              icon: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: _uploadProgress,
                  color: Colors.white,
                ),
              ),
              label: const Text('Uploading...'),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // GitHub URL option (recommended for free plan)
                FloatingActionButton.small(
                  heroTag: 'github',
                  onPressed: _showGitHubUrlDialog,
                  backgroundColor: Colors.grey.shade800,
                  child: const Icon(Icons.link, color: Colors.white),
                ),
                const SizedBox(height: 8),
                // Upload APK option
                FloatingActionButton.extended(
                  heroTag: 'upload',
                  onPressed: _showUploadDialog,
                  icon: const Icon(Icons.upload),
                  label: const Text('Add Version'),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_upload, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            'No versions uploaded yet',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Upload your first APK to get started',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  void _showUploadDialog() {
    final versionNameController = TextEditingController();
    final versionCodeController = TextEditingController();
    final releaseNotesController = TextEditingController();
    File? selectedFile;
    bool isRequired = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.upload_file, color: Colors.blue),
              SizedBox(width: 8),
              Text('Upload New Version'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Version Name
                TextField(
                  controller: versionNameController,
                  decoration: const InputDecoration(
                    labelText: 'Version Name *',
                    hintText: 'e.g., 2.1.0',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.tag),
                  ),
                ),
                const SizedBox(height: 16),

                // Version Code
                TextField(
                  controller: versionCodeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Version Code *',
                    hintText: 'e.g., 210',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.code),
                    helperText: 'Must be higher than previous version',
                  ),
                ),
                const SizedBox(height: 16),

                // Release Notes
                TextField(
                  controller: releaseNotesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Release Notes',
                    hintText: 'What\'s new in this version...',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),

                // APK File Picker
                InkWell(
                  onTap: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['apk'],
                    );
                    if (result != null && result.files.single.path != null) {
                      setDialogState(() {
                        selectedFile = File(result.files.single.path!);
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: selectedFile != null ? Colors.green : Colors.grey,
                        width: selectedFile != null ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selectedFile != null ? Icons.check_circle : Icons.android,
                          color: selectedFile != null ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            selectedFile != null
                                ? selectedFile!.path.split('/').last
                                : 'Select APK file',
                            style: TextStyle(
                              color: selectedFile != null ? Colors.green : Colors.grey,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Required Update Toggle
                SwitchListTile(
                  title: const Text('Required Update'),
                  subtitle: const Text('Force users to update'),
                  value: isRequired,
                  onChanged: (v) => setDialogState(() => isRequired = v),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.cloud_upload),
              label: const Text('Upload'),
              onPressed: selectedFile == null ||
                      versionNameController.text.isEmpty ||
                      versionCodeController.text.isEmpty
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      await _uploadVersion(
                        versionName: versionNameController.text,
                        versionCode: int.tryParse(versionCodeController.text) ?? 0,
                        releaseNotes: releaseNotesController.text,
                        apkFile: selectedFile!,
                        isRequired: isRequired,
                      );
                    },
            ),
          ],
        ),
      ),
    );
  }

  /// Show dialog to add version from GitHub URL (Free plan friendly!)
  void _showGitHubUrlDialog() {
    final versionNameController = TextEditingController();
    final versionCodeController = TextEditingController();
    final releaseNotesController = TextEditingController();
    final downloadUrlController = TextEditingController();
    bool isRequired = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.link, color: Colors.blue),
              SizedBox(width: 8),
              Text('Add from GitHub'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Recommended for Firebase free plan! Host APK on GitHub and link here.',
                          style: TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Version Name
                TextField(
                  controller: versionNameController,
                  decoration: const InputDecoration(
                    labelText: 'Version Name *',
                    hintText: 'e.g., 2.0.1',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.tag),
                  ),
                ),
                const SizedBox(height: 16),

                // Version Code
                TextField(
                  controller: versionCodeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Version Code *',
                    hintText: 'e.g., 201',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.code),
                    helperText: 'Must be higher than previous version',
                  ),
                ),
                const SizedBox(height: 16),

                // GitHub Download URL
                TextField(
                  controller: downloadUrlController,
                  decoration: const InputDecoration(
                    labelText: 'GitHub Download URL *',
                    hintText: 'https://github.com/.../releases/download/...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.download),
                    helperText: 'Direct APK download link from GitHub Releases',
                  ),
                ),
                const SizedBox(height: 16),

                // Release Notes
                TextField(
                  controller: releaseNotesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Release Notes',
                    hintText: 'What\'s new in this version...',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),

                // Required Update Toggle
                SwitchListTile(
                  title: const Text('Required Update'),
                  subtitle: const Text('Force users to update'),
                  value: isRequired,
                  onChanged: (v) => setDialogState(() => isRequired = v),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Version'),
              onPressed: downloadUrlController.text.isEmpty ||
                      versionNameController.text.isEmpty ||
                      versionCodeController.text.isEmpty
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      await _addVersionFromUrl(
                        versionName: versionNameController.text,
                        versionCode: int.tryParse(versionCodeController.text) ?? 0,
                        downloadUrl: downloadUrlController.text,
                        releaseNotes: releaseNotesController.text,
                        isRequired: isRequired,
                      );
                    },
            ),
          ],
        ),
      ),
    );
  }

  /// Add version entry with GitHub URL (no upload needed)
  Future<void> _addVersionFromUrl({
    required String versionName,
    required int versionCode,
    required String downloadUrl,
    required String releaseNotes,
    required bool isRequired,
  }) async {
    setState(() => _isLoading = true);

    try {
      final firestore = FirebaseFirestore.instance;
      
      // Create version document with GitHub URL
      await firestore.collection('app_versions').add({
        'versionName': versionName,
        'versionCode': versionCode,
        'downloadUrl': downloadUrl,
        'releaseNotes': releaseNotes.isNotEmpty ? releaseNotes : null,
        'isRequired': isRequired,
        'isActive': true,
        'releaseDate': FieldValue.serverTimestamp(),
        'downloadCount': 0,
        'fileSize': 0, // Unknown for external URLs
        'minSupportedApiVersion': AppConstants.apiVersion,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Version added successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
        _loadVersions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Text('Failed to add version: $e'),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _uploadVersion({
    required String versionName,
    required int versionCode,
    required String releaseNotes,
    required File apkFile,
    required bool isRequired,
  }) async {
    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });

    final result = await _updateService.uploadNewVersion(
      versionName: versionName,
      versionCode: versionCode,
      apkFile: apkFile,
      releaseNotes: releaseNotes.isNotEmpty ? releaseNotes : null,
      isRequired: isRequired,
      onProgress: (progress) {
        setState(() => _uploadProgress = progress);
      },
    );

    setState(() => _isUploading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                result != null ? Icons.check_circle : Icons.error,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(result != null
                  ? 'Version $versionName uploaded successfully!'
                  : 'Failed to upload version'),
            ],
          ),
          backgroundColor: result != null ? Colors.green : Colors.red,
        ),
      );

      if (result != null) {
        _loadVersions();
      }
    }
  }

  Future<void> _toggleActive(AppVersion version) async {
    final success = await _updateService.toggleVersionActive(
      version.id,
      !version.isActive,
    );
    if (success) _loadVersions();
  }

  Future<void> _toggleRequired(AppVersion version) async {
    final success = await _updateService.setVersionRequired(
      version.id,
      !version.isRequired,
    );
    if (success) _loadVersions();
  }

  void _showNotificationDialog(AppVersion version) {
    final titleController = TextEditingController(
      text: 'Update Available: v${version.versionName}',
    );
    final messageController = TextEditingController(
      text: version.releaseNotes ?? 'A new version of UniTrack is available. Update now for the latest features and improvements!',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.orange),
            SizedBox(width: 8),
            Text('Send Update Notification'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Notification Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.send),
            label: const Text('Send to All Users'),
            onPressed: () async {
              Navigator.pop(ctx);
              await _sendNotification(
                title: titleController.text,
                message: messageController.text,
                versionName: version.versionName,
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _sendNotification({
    required String title,
    required String message,
    required String versionName,
  }) async {
    _showLoadingDialog('Sending notifications...');

    final success = await _updateService.sendUpdateNotification(
      title: title,
      message: message,
      versionName: versionName,
    );

    if (mounted) Navigator.pop(context);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle : Icons.error,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(success
                  ? 'Notification sent to all users!'
                  : 'Failed to send notification'),
            ],
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteVersion(AppVersion version) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Version'),
        content: Text(
          'Delete version ${version.versionName}? This will remove it from the available updates.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _updateService.deleteVersion(version.id);
      if (success) _loadVersions();
    }
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
      ),
    );
  }
}

/// Version card widget
class _VersionCard extends StatelessWidget {
  final AppVersion version;
  final bool isLatest;
  final VoidCallback onToggleActive;
  final VoidCallback onToggleRequired;
  final VoidCallback onSendNotification;
  final VoidCallback onDelete;

  const _VersionCard({
    required this.version,
    required this.isLatest,
    required this.onToggleActive,
    required this.onToggleRequired,
    required this.onSendNotification,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isLatest ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isLatest
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: version.isActive
                  ? (isLatest ? theme.colorScheme.primaryContainer : null)
                  : Colors.grey.shade200,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                // Version badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: version.isActive ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'v${version.versionName}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (isLatest)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'LATEST',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (version.isRequired)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'REQUIRED',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const Spacer(),
                PopupMenuButton<String>(
                  onSelected: (action) {
                    switch (action) {
                      case 'toggle_active':
                        onToggleActive();
                        break;
                      case 'toggle_required':
                        onToggleRequired();
                        break;
                      case 'notify':
                        onSendNotification();
                        break;
                      case 'delete':
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'toggle_active',
                      child: Row(
                        children: [
                          Icon(
                            version.isActive ? Icons.visibility_off : Icons.visibility,
                            color: version.isActive ? Colors.grey : Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Text(version.isActive ? 'Deactivate' : 'Activate'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle_required',
                      child: Row(
                        children: [
                          Icon(
                            version.isRequired ? Icons.lock_open : Icons.lock,
                            color: version.isRequired ? Colors.grey : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Text(version.isRequired ? 'Make Optional' : 'Make Required'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'notify',
                      child: Row(
                        children: [
                          Icon(Icons.notifications, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Send Notification'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info row
                Row(
                  children: [
                    _InfoChip(
                      icon: Icons.code,
                      label: 'Code: ${version.versionCode}',
                    ),
                    const SizedBox(width: 8),
                    _InfoChip(
                      icon: Icons.storage,
                      label: version.formattedSize,
                    ),
                    const SizedBox(width: 8),
                    _InfoChip(
                      icon: Icons.download,
                      label: '${version.downloadCount} downloads',
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Release date
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      'Released: ${_formatDate(version.releaseDate)}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),

                // Release notes
                if (version.releaseNotes != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Release Notes:',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    version.releaseNotes!,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}
