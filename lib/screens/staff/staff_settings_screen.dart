import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import '../../services/update_service.dart';
import '../../services/auth_service.dart';
import '../common/privacy_policy_screen.dart';
import '../common/help_support_screen.dart';
import 'edit_profile_screen.dart';

/// Settings screen for staff members
class StaffSettingsScreen extends StatefulWidget {
  const StaffSettingsScreen({super.key});
  
  @override
  State<StaffSettingsScreen> createState() => _StaffSettingsScreenState();
}

class _StaffSettingsScreenState extends State<StaffSettingsScreen> {
  bool _notificationsEnabled = true;
  
  @override
  void initState() {
    super.initState();
    _loadNotificationPref();
  }
  
  Future<void> _loadNotificationPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      });
    }
  }
  
  Future<void> _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    if (mounted) {
      setState(() => _notificationsEnabled = value);
    }
  }
  
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
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                          );
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
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const EditProfileScreen(),
                            ),
                          );
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
                        value: _notificationsEnabled,
                        onChanged: (value) {
                          _toggleNotifications(value);
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
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                          );
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
                            Icons.help_outline,
                            color: AppColors.primary,
                          ),
                        ),
                        title: const Text('Help & Support'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Account section
                _buildSectionHeader(context, 'Account'),
                Card(
                  child: Column(
                    children: [
                      // Sign Out button
                      ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.logout,
                            color: AppColors.primary,
                          ),
                        ),
                        title: const Text('Sign Out'),
                        subtitle: const Text('Sign out of your account'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          _showSignOutDialog(context);
                        },
                      ),
                      const Divider(height: 1),
                      // Delete Account button
                      ListTile(
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
                    ],
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
    // Load saved schedule from SharedPreferences
    SharedPreferences.getInstance().then((prefs) {
      final startHour = prefs.getInt('autohide_start_hour') ?? 17;
      final startMinute = prefs.getInt('autohide_start_minute') ?? 0;
      final endHour = prefs.getInt('autohide_end_hour') ?? 8;
      final endMinute = prefs.getInt('autohide_end_minute') ?? 0;
      final hideWeekends = prefs.getBool('autohide_weekends') ?? true;
      final scheduleEnabled = prefs.getBool('autohide_enabled') ?? false;
      
      TimeOfDay startTime = TimeOfDay(hour: startHour, minute: startMinute);
      TimeOfDay endTime = TimeOfDay(hour: endHour, minute: endMinute);
      bool weekends = hideWeekends;
      bool enabled = scheduleEnabled;
      
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogCtx, setDialogState) => AlertDialog(
            title: const Text('Auto-hide Schedule'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('Enable Schedule'),
                  subtitle: Text(
                    enabled ? 'Location auto-hides on schedule' : 'Schedule is disabled',
                  ),
                  value: enabled,
                  onChanged: (value) {
                    setDialogState(() => enabled = value);
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  enabled: enabled,
                  title: const Text('Start Time'),
                  subtitle: Text(startTime.format(dialogCtx)),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: dialogCtx,
                      initialTime: startTime,
                    );
                    if (picked != null) {
                      setDialogState(() => startTime = picked);
                    }
                  },
                ),
                ListTile(
                  enabled: enabled,
                  title: const Text('End Time'),
                  subtitle: Text(endTime.format(dialogCtx)),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: dialogCtx,
                      initialTime: endTime,
                    );
                    if (picked != null) {
                      setDialogState(() => endTime = picked);
                    }
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Weekends'),
                  subtitle: const Text('Hide all day on weekends'),
                  value: weekends,
                  onChanged: enabled
                      ? (value) {
                          setDialogState(() => weekends = value);
                        }
                      : null,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('autohide_enabled', enabled);
                  await prefs.setInt('autohide_start_hour', startTime.hour);
                  await prefs.setInt('autohide_start_minute', startTime.minute);
                  await prefs.setInt('autohide_end_hour', endTime.hour);
                  await prefs.setInt('autohide_end_minute', endTime.minute);
                  await prefs.setBool('autohide_weekends', weekends);
                  
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  
                  if (dialogCtx.mounted) {
                    ScaffoldMessenger.of(dialogCtx).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(enabled ? 'Schedule saved' : 'Schedule disabled'),
                          ],
                        ),
                        backgroundColor: AppColors.accent,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
    });
  }
  
  void _showSignOutDialog(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Sign Out'),
          ],
        ),
        content: const Text(
          'Are you sure you want to sign out?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await authProvider.signOut();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
  
  void _showDeleteAccountDialog(BuildContext context) {
    final passwordController = TextEditingController();
    bool isDeleting = false;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: AppColors.error),
              SizedBox(width: 8),
              Text('Delete Account'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently removed.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirm your password',
                  hintText: 'Enter your password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.lock),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isDeleting ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isDeleting
                  ? null
                  : () async {
                      if (passwordController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter your password')),
                        );
                        return;
                      }
                      setDialogState(() => isDeleting = true);
                      try {
                        final authProvider = context.read<AuthProvider>();
                        final user = authProvider.user;
                        if (user == null) return;
                        
                        // Re-authenticate first
                        final authService = AuthService();
                        await authService.reauthenticate(
                          user.email,
                          passwordController.text,
                        );
                        
                        // Delete the account
                        await authService.deleteAccount();
                        
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        
                        // Sign out and go to login
                        await authProvider.signOut();
                      } catch (e) {
                        setDialogState(() => isDeleting = false);
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                e.toString().contains('wrong-password') || e.toString().contains('invalid-credential')
                                    ? 'Incorrect password. Please try again.'
                                    : 'Error: $e',
                              ),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
              ),
              child: isDeleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Delete'),
            ),
          ],
        ),
      ),
    );
    
    // Dispose controller when dialog closes
    // (StatefulBuilder keeps it alive until dialog pops)
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
