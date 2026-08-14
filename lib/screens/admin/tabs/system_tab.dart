import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../../providers/providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../services/offline_cache_service.dart';
import '../../../services/broadcast_service.dart';
import '../version_management_screen.dart';

/// System Tab - Broadcast notifications, data export, system health
class SystemTab extends StatefulWidget {
  const SystemTab({super.key});

  @override
  State<SystemTab> createState() => _SystemTabState();
}

class _SystemTabState extends State<SystemTab> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _isSending = false;
  String _selectedAudience = 'all';

  // System stats
  int _totalDocuments = 0;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadSystemStats();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _loadSystemStats() async {
    setState(() => _isLoadingStats = true);
    try {
      final firestore = FirebaseFirestore.instance;

      // Count documents in main collections
      final usersCount = await firestore.collection('users').count().get();
      final notificationsCount = await firestore
          .collection('notifications')
          .count()
          .get();
      final versionsCount = await firestore
          .collection('app_versions')
          .count()
          .get();

      setState(() {
        _totalDocuments =
            (usersCount.count ?? 0) +
            (notificationsCount.count ?? 0) +
            (versionsCount.count ?? 0);
        _isLoadingStats = false;
      });
    } catch (e) {
      setState(() => _isLoadingStats = false);
    }
  }

  Future<void> _sendBroadcastNotification() async {
    if (_titleController.text.isEmpty || _bodyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in title and message')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.campaign, color: Colors.orange),
            SizedBox(width: 8),
            Text('Send Broadcast'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Send notification to: ${_getAudienceLabel()}'),
            const SizedBox(height: 12),
            Text(
              'Title: ${_titleController.text}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Message: ${_bodyController.text}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.send),
            label: const Text('Send'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isSending = true);

    try {
      final sentCount = await BroadcastService.instance.sendBroadcastToFilter(
        title: _titleController.text,
        body: _bodyController.text,
        filter: _selectedAudience,
      );

      if (mounted) {
        _titleController.clear();
        _bodyController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Broadcast sent to $sentCount users'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Failed to send broadcast. Please try again.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  String _getAudienceLabel() {
    switch (_selectedAudience) {
      case 'students':
        return 'All Students';
      case 'admins':
        return 'All Admins';
      default:
        return 'All Users';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // System Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'System Information',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SystemInfoRow(
                    icon: Icons.apps,
                    label: 'App Version',
                    value: 'v${AppConstants.appVersion}',
                  ),
                  const Divider(),
                  _SystemInfoRow(
                    icon: Icons.code,
                    label: 'Version Code',
                    value: '${AppConstants.versionCode}',
                  ),
                  const Divider(),
                  _SystemInfoRow(
                    icon: Icons.storage,
                    label: 'Database Documents',
                    value: _isLoadingStats ? 'Loading...' : '$_totalDocuments',
                  ),
                  const Divider(),
                  _SystemInfoRow(
                    icon: Icons.cloud,
                    label: 'Firebase Project',
                    value: Firebase.app().options.projectId,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Broadcast Notification Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.campaign, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        'Broadcast Notification',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Send a notification to all users or specific groups',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 16),

                  // Audience selector
                  Text('Target Audience', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('All Users'),
                        selected: _selectedAudience == 'all',
                        onSelected: (_) =>
                            setState(() => _selectedAudience = 'all'),
                      ),
                      ChoiceChip(
                        label: const Text('Students'),
                        selected: _selectedAudience == 'students',
                        onSelected: (_) =>
                            setState(() => _selectedAudience = 'students'),
                      ),
                      ChoiceChip(
                        label: const Text('Admins'),
                        selected: _selectedAudience == 'admins',
                        onSelected: (_) =>
                            setState(() => _selectedAudience = 'admins'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Notification Title',
                      hintText: 'e.g., Important Announcement',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.title),
                    ),
                    maxLength: 50,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _bodyController,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      hintText: 'Enter your message here...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.message),
                    ),
                    maxLines: 3,
                    maxLength: 200,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSending ? null : _sendBroadcastNotification,
                      icon: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      label: Text(_isSending ? 'Sending...' : 'Send Broadcast'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Quick Actions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.flash_on, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Quick Actions',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _QuickActionButton(
                        icon: Icons.system_update,
                        label: 'App Versions',
                        color: Colors.green,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const VersionManagementScreen(),
                          ),
                        ),
                      ),
                      _QuickActionButton(
                        icon: Icons.refresh,
                        label: 'Refresh Stats',
                        color: Colors.blue,
                        onTap: () {
                          _loadSystemStats();
                          context.read<AdminProvider>().refresh();
                        },
                      ),
                      _QuickActionButton(
                        icon: Icons.cleaning_services,
                        label: 'Clear Cache',
                        color: Colors.purple,
                        onTap: () async {
                          try {
                            await OfflineCacheService().clearCache();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Text('Cache cleared successfully'),
                                    ],
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to clear cache: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Build Info
          Card(
            color: Colors.grey.shade100,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.build, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        'Build Configuration',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Platform: Web (PWA)\n'
                    'Renderer: CanvasKit\n'
                    'Hosting: Firebase\n'
                    'Firebase: Enabled',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SystemInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withAlpha(25),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
