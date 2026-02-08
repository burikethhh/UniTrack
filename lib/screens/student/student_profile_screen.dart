import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../widgets/widgets.dart';
import '../../services/update_service.dart';
import '../../services/push_notification_service.dart';
import '../common/privacy_policy_screen.dart';
import '../common/help_support_screen.dart';
import '../staff/edit_profile_screen.dart';

/// Profile screen for students
class StudentProfileScreen extends StatelessWidget {
  const StudentProfileScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          final user = authProvider.user;
          
          if (user == null) {
            return const Center(
              child: Text('No user data available'),
            );
          }
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Profile card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Avatar and name
                        Stack(
                          children: [
                            UserAvatar(
                              imageUrl: user.photoUrl,
                              initials: user.initials,
                              size: 90,
                              showBorder: true,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          user.fullName,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        if (user.department != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            user.department!,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        // Role badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Student',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Location sharing toggle
                Consumer<LocationProvider>(
                  builder: (context, locationProvider, _) {
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: AppColors.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: locationProvider.isTracking
                                        ? AppColors.accent.withValues(alpha: 0.1)
                                        : AppColors.textSecondary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    locationProvider.isTracking
                                        ? Icons.location_on
                                        : Icons.location_off,
                                    color: locationProvider.isTracking
                                        ? AppColors.accent
                                        : AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Location Sharing',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        locationProvider.isTracking
                                            ? 'Your location is visible'
                                            : 'Your location is hidden',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: locationProvider.isTracking,
                                  onChanged: (value) {
                                    if (value) {
                                      locationProvider.startTracking();
                                    } else {
                                      locationProvider.stopTracking();
                                    }
                                  },
                                  activeTrackColor: AppColors.accent.withValues(alpha: 0.5),
                                  thumbColor: WidgetStateProperty.resolveWith((states) {
                                    if (states.contains(WidgetState.selected)) {
                                      return AppColors.accent;
                                    }
                                    return null;
                                  }),
                                ),
                              ],
                            ),
                            if (locationProvider.isTracking) ...[
                              const Divider(height: 24),
                              Row(
                                children: [
                                  Icon(
                                    locationProvider.isWithinCampus
                                        ? Icons.check_circle
                                        : Icons.info_outline,
                                    color: locationProvider.isWithinCampus
                                        ? AppColors.accent
                                        : AppColors.info,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    locationProvider.isWithinCampus
                                        ? 'Within campus boundaries'
                                        : 'Outside campus boundaries',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),
                
                // Settings section card
                _buildSectionCard(
                  context,
                  title: 'Settings',
                  icon: Icons.settings_outlined,
                  children: [
                    _buildMenuTile(
                      icon: Icons.person_outline,
                      iconColor: AppColors.primary,
                      title: 'Edit Profile',
                      subtitle: 'Update name, department, photo',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 56),
                    _buildMenuTile(
                      icon: Icons.notifications_outlined,
                      iconColor: Colors.orange,
                      title: 'Notifications',
                      subtitle: 'Manage notification preferences',
                      onTap: () {
                        _showNotificationSettings(context);
                      },
                    ),
                    const Divider(height: 1, indent: 56),
                    _buildMenuTile(
                      icon: Icons.favorite_outline,
                      iconColor: Colors.pink,
                      title: 'Favorites',
                      subtitle: 'View saved faculty members',
                      onTap: () {
                        _showFavoritesInfo(context);
                      },
                    ),
                    const Divider(height: 1, indent: 56),
                    _buildMenuTile(
                      icon: Icons.dark_mode_outlined,
                      iconColor: Colors.deepPurple,
                      title: 'Appearance',
                      subtitle: 'Theme and display settings',
                      onTap: () {
                        _showAppearanceSettings(context);
                      },
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // About section card
                _buildSectionCard(
                  context,
                  title: 'About',
                  icon: Icons.info_outline,
                  children: [
                    _buildMenuTile(
                      icon: Icons.info_outline,
                      iconColor: AppColors.info,
                      title: 'About UniTrack',
                      subtitle: 'Version ${AppConstants.appVersion}',
                      onTap: () {
                        _showAboutDialog(context);
                      },
                    ),
                    const Divider(height: 1, indent: 56),
                    const _UpdateCheckMenuItem(),
                    const Divider(height: 1, indent: 56),
                    _buildMenuTile(
                      icon: Icons.privacy_tip_outlined,
                      iconColor: Colors.teal,
                      title: 'Privacy Policy',
                      subtitle: 'How we protect your data',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 56),
                    _buildMenuTile(
                      icon: Icons.help_outline,
                      iconColor: Colors.indigo,
                      title: 'Help & Support',
                      subtitle: 'Get help with UniTrack',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
                        );
                      },
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Sign out button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showLogoutDialog(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.logout),
                    label: const Text(
                      'Sign Out',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Footer
                Text(
                  '© 2026 ${AppConstants.universityShortName}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
  
  Widget _buildMenuTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: AppColors.textSecondary.withValues(alpha: 0.5),
      ),
      onTap: onTap,
    );
  }
  
  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.location_on,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(AppConstants.appName),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppConstants.appTagline,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Text('Version: ${AppConstants.appVersion}'),
            const SizedBox(height: 8),
            Text(
              'Developed for ${AppConstants.universityName}',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            const Text(
              'Proposed by: Christian Keth Aguacito',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  void _showNotificationSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _NotificationSettingsSheet(),
    );
  }
  
  void _showFavoritesInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.favorite_outline,
          size: 48,
          color: Colors.pink.withValues(alpha: 0.7),
        ),
        title: const Text('Favorites'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Save your favorite faculty members for quick access.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.pink.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.pink, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Coming soon in a future update!',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.pink.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
  
  void _showAppearanceSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.dark_mode_outlined,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Appearance',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Theme options
            const Text(
              'Theme',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            
            // Light theme (current)
            _buildThemeOption(
              context,
              icon: Icons.light_mode,
              title: 'Light',
              subtitle: 'Default bright theme',
              isSelected: true,
              onTap: () {},
            ),
            const SizedBox(height: 8),
            
            // Dark theme (coming soon)
            _buildThemeOption(
              context,
              icon: Icons.dark_mode,
              title: 'Dark',
              subtitle: 'Coming soon',
              isSelected: false,
              isDisabled: true,
              onTap: () {},
            ),
            const SizedBox(height: 8),
            
            // System theme (coming soon)
            _buildThemeOption(
              context,
              icon: Icons.brightness_auto,
              title: 'System',
              subtitle: 'Follow device settings - Coming soon',
              isSelected: false,
              isDisabled: true,
              onTap: () {},
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
  
  Widget _buildThemeOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    bool isDisabled = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: isDisabled ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : isDisabled
                  ? AppColors.border.withValues(alpha: 0.3)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? AppColors.primary
                  : isDisabled
                      ? AppColors.textSecondary.withValues(alpha: 0.5)
                      : AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDisabled
                          ? AppColors.textSecondary.withValues(alpha: 0.5)
                          : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDisabled
                          ? AppColors.textSecondary.withValues(alpha: 0.4)
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: AppColors.primary,
              ),
          ],
        ),
      ),
    );
  }
  
  void _showLogoutDialog(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await authProvider.signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

/// Widget for checking app updates in profile screen
class _UpdateCheckMenuItem extends StatefulWidget {
  const _UpdateCheckMenuItem();

  @override
  State<_UpdateCheckMenuItem> createState() => _UpdateCheckMenuItemState();
}

class _UpdateCheckMenuItemState extends State<_UpdateCheckMenuItem> {
  final UpdateService _updateService = UpdateService();
  bool _isChecking = false;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: _isChecking
            ? const Padding(
                padding: EdgeInsets.all(10),
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.system_update, color: Colors.green, size: 20),
      ),
      title: const Text(
        'Check for Updates',
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        'Download the latest version',
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: AppColors.textSecondary.withValues(alpha: 0.5),
      ),
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

/// Notification settings bottom sheet
class _NotificationSettingsSheet extends StatefulWidget {
  const _NotificationSettingsSheet();

  @override
  State<_NotificationSettingsSheet> createState() => _NotificationSettingsSheetState();
}

class _NotificationSettingsSheetState extends State<_NotificationSettingsSheet> {
  bool _isLoading = true;
  bool _notificationsEnabled = false;
  AuthorizationStatus _authStatus = AuthorizationStatus.notDetermined;
  
  @override
  void initState() {
    super.initState();
    _loadNotificationStatus();
  }
  
  Future<void> _loadNotificationStatus() async {
    try {
      final settings = await PushNotificationService().getNotificationSettings();
      if (mounted) {
        setState(() {
          _authStatus = settings.authorizationStatus;
          _notificationsEnabled = settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  String _getStatusText() {
    switch (_authStatus) {
      case AuthorizationStatus.authorized:
        return 'Enabled';
      case AuthorizationStatus.provisional:
        return 'Provisional';
      case AuthorizationStatus.denied:
        return 'Disabled';
      case AuthorizationStatus.notDetermined:
        return 'Not set';
    }
  }
  
  Color _getStatusColor() {
    switch (_authStatus) {
      case AuthorizationStatus.authorized:
      case AuthorizationStatus.provisional:
        return Colors.green;
      case AuthorizationStatus.denied:
        return Colors.red;
      case AuthorizationStatus.notDetermined:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.notifications_outlined,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Notifications',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Status card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getStatusColor().withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _getStatusColor().withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _notificationsEnabled
                      ? Icons.notifications_active
                      : Icons.notifications_off,
                  color: _getStatusColor(),
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Push Notifications',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(),
                        ),
                      ),
                      const SizedBox(height: 4),
                      _isLoading
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              'Status: ${_getStatusText()}',
                              style: TextStyle(
                                fontSize: 13,
                                color: _getStatusColor().withValues(alpha: 0.8),
                              ),
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Info text
          Text(
            'Receive notifications when:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          _buildNotificationItem(
            icon: Icons.person_pin_circle,
            text: 'A faculty member becomes available',
          ),
          _buildNotificationItem(
            icon: Icons.message,
            text: 'You receive a ping response',
          ),
          _buildNotificationItem(
            icon: Icons.update,
            text: 'App updates are available',
          ),
          
          const SizedBox(height: 20),
          
          // Note
          if (_authStatus == AuthorizationStatus.denied)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'To enable notifications, go to your device Settings > Apps > UniTrack > Notifications',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 12),
        ],
      ),
    );
  }
  
  Widget _buildNotificationItem({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
