import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';

/// Help & Support Screen with FAQ and contact options
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.help_outline,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Need Help?',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Find answers to common questions or contact support',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // FAQ Section
            Text(
              'Frequently Asked Questions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            _buildFAQItem(
              context,
              'How do I find a faculty member?',
              'Use the Directory tab to search by name or department. You can also use the Map tab to see faculty locations in real-time.',
            ),

            _buildFAQItem(
              context,
              'What do the status colors mean?',
              '🟢 Available - Open for consultations\n🟡 Busy - Currently occupied\n🔵 In Meeting - In a scheduled meeting\n🟣 Teaching - Conducting classes\n🟤 On Break - Temporarily away\n⚪ Out of Office - Not on campus\n🔴 Do Not Disturb - Please do not interrupt',
            ),

            _buildFAQItem(
              context,
              'Why can\'t I see a faculty\'s location?',
              'Faculty members control their own location visibility. If you can\'t see their location, they may have disabled sharing or are currently off-campus.',
            ),

            _buildFAQItem(
              context,
              'How do I enable location sharing? (Staff)',
              'Go to Settings > Privacy & Location > Enable "Location Sharing". Your location will only be visible while you\'re within campus boundaries.',
            ),

            _buildFAQItem(
              context,
              'Does the app work offline?',
              'Yes! UniTrack caches faculty data locally. You can view the directory offline, but real-time locations require an internet connection.',
            ),

            _buildFAQItem(
              context,
              'How do I update my status? (Staff)',
              'On the Dashboard, tap the status dropdown to select your current availability. You can also add a custom message to provide more context.',
            ),

            _buildFAQItem(
              context,
              'Is my location tracked when I\'m off campus?',
              'No. UniTrack uses geofencing - your location is only shared when you\'re within campus boundaries. No location history is stored.',
            ),

            _buildFAQItem(
              context,
              'How do I reset my password?',
              'On the login screen, tap "Forgot Password?" and enter your email. You\'ll receive a password reset link.',
            ),

            const SizedBox(height: 24),

            // Contact Section
            Text(
              'Contact Support',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            _buildContactCard(
              context,
              icon: Icons.email_outlined,
              title: 'Email Support',
              subtitle: 'support@sksu.edu.ph',
              onTap: () => _launchEmail('support@sksu.edu.ph'),
            ),

            _buildContactCard(
              context,
              icon: Icons.school_outlined,
              title: 'University Website',
              subtitle: 'www.sksu.edu.ph',
              onTap: () => _launchUrl('https://www.sksu.edu.ph'),
            ),

            _buildContactCard(
              context,
              icon: Icons.bug_report_outlined,
              title: 'Report a Bug',
              subtitle: 'Help us improve UniTrack',
              onTap: () => _launchEmail(
                'support@sksu.edu.ph',
                subject: 'UniTrack Bug Report - v${AppConstants.appVersion}',
                body: 'Please describe the issue:\n\n\n\nSteps to reproduce:\n1. \n2. \n3. \n\nDevice: \nAndroid Version: ',
              ),
            ),

            const SizedBox(height: 24),

            // App Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: AppColors.accentGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppConstants.appName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Version ${AppConstants.appVersion}',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '© 2026 ${AppConstants.universityShortName}',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQItem(BuildContext context, String question, String answer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Icon(
          Icons.help_outline,
          color: AppColors.accent,
          size: 20,
        ),
        title: Text(
          question,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        children: [
          Text(
            answer,
            style: TextStyle(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.accent),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  Future<void> _launchEmail(String email, {String? subject, String? body}) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: _encodeQueryParameters({
        if (subject != null) 'subject': subject,
        if (body != null) 'body': body,
      }),
    );
    
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String? _encodeQueryParameters(Map<String, String> params) {
    if (params.isEmpty) return null;
    return params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }
}
