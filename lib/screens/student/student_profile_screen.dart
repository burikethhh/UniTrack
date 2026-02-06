import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/widgets.dart';
import '../../services/update_service.dart';
import '../common/privacy_policy_screen.dart';
import '../common/help_support_screen.dart';

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
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Avatar and name
                UserAvatar(
                  imageUrl: user.photoUrl,
                  initials: user.initials,
                  size: 100,
                  showBorder: true,
                ),
                const SizedBox(height: 16),
                Text(
                  user.fullName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (user.department != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    user.department!,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                
                const SizedBox(height: 8),
                
                // Role badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
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
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Settings section
                _buildSectionHeader(context, 'Settings'),
                const SizedBox(height: 12),
                
                _buildMenuItem(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  subtitle: 'Manage notification preferences',
                  onTap: () {
                    // TODO: Navigate to notifications settings
                  },
                ),
                _buildMenuItem(
                  icon: Icons.favorite_outline,
                  title: 'Favorites',
                  subtitle: 'View saved faculty members',
                  onTap: () {
                    // TODO: Navigate to favorites
                  },
                ),
                _buildMenuItem(
                  icon: Icons.dark_mode_outlined,
                  title: 'Appearance',
                  subtitle: 'Theme and display settings',
                  onTap: () {
                    // TODO: Navigate to appearance settings
                  },
                ),
                
                const SizedBox(height: 24),
                
                // About section
                _buildSectionHeader(context, 'About'),
                const SizedBox(height: 12),
                
                _buildMenuItem(
                  icon: Icons.info_outline,
                  title: 'About UniTrack',
                  subtitle: 'Version ${AppConstants.appVersion}',
                  onTap: () {
                    _showAboutDialog(context);
                  },
                ),
                const _UpdateCheckMenuItem(),
                _buildMenuItem(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  subtitle: 'How we protect your data',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                    );
                  },
                ),
                _buildMenuItem(
                  icon: Icons.help_outline,
                  title: 'Help & Support',
                  subtitle: 'Get help with UniTrack',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
                    );
                  },
                ),
                
                const SizedBox(height: 32),
                
                // Logout button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showLogoutDialog(context);
                    },
                    icon: const Icon(Icons.logout, color: AppColors.error),
                    label: const Text(
                      'Sign Out',
                      style: TextStyle(color: AppColors.error),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
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
  
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
  
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(title),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: AppColors.textSecondary,
        ),
        onTap: onTap,
      ),
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
  
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthProvider>().signOut();
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
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppColors.divider,
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
      ),
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
