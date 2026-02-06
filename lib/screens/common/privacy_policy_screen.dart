import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';

/// Privacy Policy Screen
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Center(
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: AppColors.accentGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.privacy_tip,
                      size: 30,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${AppConstants.appName} Privacy Policy',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Last updated: February 2026',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            _buildSection(
              context,
              'Data We Collect',
              Icons.folder_outlined,
              [
                'Basic profile information (name, email, department)',
                'Location data (only when you enable sharing)',
                'Device information for push notifications',
                'App usage analytics (anonymous)',
              ],
            ),

            _buildSection(
              context,
              'How We Use Your Data',
              Icons.settings_outlined,
              [
                'Display faculty availability to students',
                'Show real-time locations on the campus map',
                'Send relevant notifications (optional)',
                'Improve app performance and features',
              ],
            ),

            _buildSection(
              context,
              'Location Privacy',
              Icons.location_on_outlined,
              [
                'Location sharing is completely optional (opt-in)',
                'You control when your location is visible',
                'Location is only shared within campus boundaries',
                'We do NOT track or store location history',
                'Auto-hide feature stops sharing after work hours',
              ],
            ),

            _buildSection(
              context,
              'Data Storage & Security',
              Icons.security_outlined,
              [
                'Data is stored securely on Firebase servers',
                'All data transmission is encrypted (HTTPS)',
                'We follow industry security best practices',
                'Your password is never stored in plain text',
              ],
            ),

            _buildSection(
              context,
              'Your Rights',
              Icons.gavel_outlined,
              [
                'Access your personal data anytime',
                'Request correction of inaccurate data',
                'Delete your account and all associated data',
                'Opt-out of notifications at any time',
                'Disable location sharing whenever you want',
              ],
            ),

            _buildSection(
              context,
              'Third-Party Services',
              Icons.cloud_outlined,
              [
                'Firebase (Authentication, Database, Storage)',
                'Google Maps/MapLibre (Campus mapping)',
                'No data is sold to third parties',
                'Analytics data is anonymized',
              ],
            ),

            const SizedBox(height: 24),

            // Contact section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.contact_support, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Questions or Concerns?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'If you have any questions about this Privacy Policy or how we handle your data, please contact:',
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    'Email: support@sksu.edu.ph',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Footer
            Center(
              child: Text(
                '© 2026 ${AppConstants.universityShortName}\nAll rights reserved.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    IconData icon,
    List<String> points,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...points.map((point) => Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    point,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
