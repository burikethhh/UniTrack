import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../models/app_version_model.dart';
import '../services/update_service.dart';
import '../core/utils/web_utils.dart';

/// Dialog for showing app update availability
class UpdateDialog extends StatefulWidget {
  final UpdateCheckResult updateResult;
  final VoidCallback? onLater;
  final VoidCallback? onUpdate;

  const UpdateDialog({
    super.key,
    required this.updateResult,
    this.onLater,
    this.onUpdate,
  });

  /// Show the update dialog
  static Future<bool?> show(
    BuildContext context, {
    required UpdateCheckResult updateResult,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: !updateResult.isRequired,
      builder: (_) => UpdateDialog(updateResult: updateResult),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  final UpdateService _updateService = UpdateService();
  bool _isDownloading = false;
  double _downloadProgress = 0;
  String _statusMessage = '';

  @override
  Widget build(BuildContext context) {
    final version = widget.updateResult.latestVersion!;
    final theme = Theme.of(context);

    return PopScope(
      canPop: !widget.updateResult.isRequired || _isDownloading,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with icon
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withAlpha(204),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(51),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.system_update,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Update Available!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'v${version.versionName}',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Required badge
                    if (widget.updateResult.isRequired)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning, color: Colors.red.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This update is required to continue using the app.',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Version info
                    Row(
                      children: [
                        _InfoTile(
                          icon: Icons.arrow_upward,
                          label: 'From',
                          value: 'v${_updateService.currentVersionName}',
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.arrow_forward, color: Colors.grey),
                        ),
                        _InfoTile(
                          icon: Icons.arrow_downward,
                          label: 'To',
                          value: 'v${version.versionName}',
                        ),
                        const SizedBox(width: 16),
                        _InfoTile(
                          icon: Icons.storage,
                          label: 'Size',
                          value: version.formattedSize,
                        ),
                      ],
                    ),

                    // Release notes
                    if (version.releaseNotes != null) ...[
                      const SizedBox(height: 20),
                      const Text(
                        "What's New:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          version.releaseNotes!,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                    ],

                    // Download progress
                    if (_isDownloading) ...[
                      const SizedBox(height: 24),
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _statusMessage,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              Text(
                                '${(_downloadProgress * 100).toInt()}%',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: _downloadProgress,
                              minHeight: 10,
                              backgroundColor: Colors.grey.shade200,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: _isDownloading
            ? null
            : [
                if (!widget.updateResult.isRequired)
                  TextButton(
                    onPressed: () {
                      widget.onLater?.call();
                      Navigator.of(context).pop(false);
                    },
                    child: const Text('Later'),
                  ),
                ElevatedButton.icon(
                  icon: Icon(kIsWeb ? Icons.refresh : Icons.download),
                  label: Text(kIsWeb ? 'Refresh Now' : 'Update Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _startDownload,
                ),
              ],
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
      ),
    );
  }

  Future<void> _startDownload() async {
    final version = widget.updateResult.latestVersion!;

    setState(() {
      _isDownloading = true;
      _statusMessage = 'Downloading...';
    });

    final success = await _updateService.downloadAndInstallUpdate(
      version,
      onProgress: (progress) {
        setState(() {
          _downloadProgress = progress;
          if (progress < 1.0) {
            _statusMessage = 'Downloading...';
          } else {
            _statusMessage = 'Installing...';
          }
        });
      },
    );

    if (mounted) {
      if (success) {
        if (kIsWeb) {
          reloadWebPage();
        }
        // Installation started
        Navigator.of(context).pop(true);
        widget.onUpdate?.call();
      } else {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Text('Download failed. Please try again.'),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
