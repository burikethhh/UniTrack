import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import '../../services/update_service.dart';

/// Settings screen for staff members
class StaffSettingsScreen extends StatelessWidget {
  const StaffSettingsScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Consumer2<AuthProvider, LocationProvider>(
        builder: (context, authProvider, locationProvider, _) {
          final user = authProvider.user;
          
          if (user == null) {
            return const Center(
              child: Text('No user data available'),
            );
          }
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile section
                _buildSectionHeader(context, 'Profile'),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: UserAvatar(
                          imageUrl: user.photoUrl,
                          initials: user.initials,
                          size: 48,
                        ),
                        title: Text(user.fullName),
                        subtitle: Text(user.email),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // TODO: Navigate to edit profile
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.badge,
                            color: AppColors.primary,
                          ),
                        ),
                        title: const Text('Department'),
                        subtitle: Text(user.department ?? 'Not set'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // TODO: Edit department
                        },
                      ),
                      if (user.position != null) ...[
                        const Divider(height: 1),
                        ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.work,
                              color: AppColors.primary,
                            ),
                          ),
                          title: const Text('Position'),
                          subtitle: Text(user.position!),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            // TODO: Edit position
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Privacy section
                _buildSectionHeader(context, 'Privacy & Location'),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: AppColors.accent,
                          ),
                        ),
                        title: const Text('Location Sharing'),
                        subtitle: Text(
                          locationProvider.isTracking
                              ? 'Your location is visible'
                              : 'Your location is hidden',
                        ),
                        value: locationProvider.isTracking,
                        onChanged: (value) {
                          if (value) {
                            locationProvider.startTracking();
                          } else {
                            locationProvider.stopTracking();
                          }
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.info.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.timer,
                            color: AppColors.info,
                          ),
                        ),
                        title: const Text('Auto-hide Schedule'),
                        subtitle: const Text('Hide location during off hours'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          _showScheduleDialog(context);
                        },
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Notifications section
                _buildSectionHeader(context, 'Notifications'),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.notifications,
                            color: AppColors.primary,
                          ),
                        ),
                        title: const Text('Push Notifications'),
                        subtitle: const Text('Receive app notifications'),
                        value: true, // TODO: Connect to actual setting
                        onChanged: (value) {
                          // TODO: Toggle notification
                        },
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // About section
                _buildSectionHeader(context, 'About'),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.info,
                            color: AppColors.primary,
                          ),
                        ),
                        title: const Text('App Version'),
                        subtitle: Text(AppConstants.appVersion),
                      ),
                      const Divider(height: 1),
                      _UpdateCheckTile(),
                      const Divider(height: 1),
                      ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.privacy_tip,
                            color: AppColors.primary,
                          ),
                        ),
                        title: const Text('Privacy Policy'),
                        trailing: const Icon(Icons.open_in_new, size: 18),
                        onTap: () {
                          // TODO: Open privacy policy
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.description,
                            color: AppColors.primary,
                          ),
                        ),
                        title: const Text('Terms of Service'),
                        trailing: const Icon(Icons.open_in_new, size: 18),
                        onTap: () {
                          // TODO: Open terms of service
                        },
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Danger zone
                _buildSectionHeader(context, 'Account'),
                Card(
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.delete_forever,
                        color: AppColors.error,
                      ),
                    ),
                    title: const Text(
                      'Delete Account',
                      style: TextStyle(color: AppColors.error),
                    ),
                    subtitle: const Text('Permanently delete your account'),
                    onTap: () {
                      _showDeleteAccountDialog(context);
                    },
                  ),
                ),
                
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
  
  void _showScheduleDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Auto-hide Schedule'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Set times when your location will automatically be hidden.',
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Start Time'),
              subtitle: const Text('5:00 PM'),
              trailing: const Icon(Icons.access_time),
              onTap: () {
                // TODO: Show time picker
              },
            ),
            ListTile(
              title: const Text('End Time'),
              subtitle: const Text('8:00 AM'),
              trailing: const Icon(Icons.access_time),
              onTap: () {
                // TODO: Show time picker
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Weekends'),
              subtitle: const Text('Hide all day on weekends'),
              value: true,
              onChanged: (value) {
                // TODO: Toggle weekend setting
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Save schedule
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
  
  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: AppColors.error),
            SizedBox(width: 8),
            Text('Delete Account'),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Delete account
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// Widget for checking app updates
class _UpdateCheckTile extends StatefulWidget {
  @override
  State<_UpdateCheckTile> createState() => _UpdateCheckTileState();
}

class _UpdateCheckTileState extends State<_UpdateCheckTile> {
  final UpdateService _updateService = UpdateService();
  bool _isChecking = false;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.green.withAlpha(25),
          borderRadius: BorderRadius.circular(10),
        ),
        child: _isChecking
            ? const Padding(
                padding: EdgeInsets.all(10),
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.system_update, color: Colors.green),
      ),
      title: const Text('Check for Updates'),
      subtitle: const Text('Download the latest version'),
      trailing: const Icon(Icons.chevron_right),
      onTap: _isChecking ? null : _checkForUpdate,
    );
  }

  Future<void> _checkForUpdate() async {
    setState(() => _isChecking = true);

    final result = await _updateService.checkForUpdate();

    if (!mounted) return;
    setState(() => _isChecking = false);

    if (result.hasUpdate) {
      UpdateDialog.show(context, updateResult: result);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text('You\'re up to date! (v${AppConstants.appVersion})'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
