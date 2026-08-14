import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/helpers.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../services/activity_log_service.dart';
import '../../widgets/widgets.dart';

/// Detailed view for a specific faculty member
class FacultyDetailScreen extends StatefulWidget {
  final String facultyId;

  const FacultyDetailScreen({super.key, required this.facultyId});

  @override
  State<FacultyDetailScreen> createState() => _FacultyDetailScreenState();
}

class _FacultyDetailScreenState extends State<FacultyDetailScreen> {
  bool _hasLoggedView = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leader Details')),
      body: Consumer<FacultyProvider>(
        builder: (context, provider, _) {
          final faculty = provider.getFacultyById(widget.facultyId);

          if (faculty == null) {
            return const Center(child: Text('Leader not found'));
          }

          // Log profile view once (not on every rebuild)
          if (!_hasLoggedView) {
            _hasLoggedView = true;
            ActivityLogService().logProfileView(faculty.user.id);
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header section
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                  ),
                  child: Column(
                    children: [
                      FacultyAvatar(
                        imageUrl: faculty.user.photoUrl,
                        initials: faculty.user.initials,
                        isOnline: faculty.isOnline,
                        size: 100,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        faculty.user.fullName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (faculty.user.position != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          faculty.user.position!,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                      if (faculty.user.department != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          faculty.user.department!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white60,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      StatusBadge(status: faculty.displayStatus, fontSize: 14),
                    ],
                  ),
                ),

                // Quick message
                if (faculty.location?.quickMessage != null)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.info.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.message, color: AppColors.info),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Quick Message',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.info,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '"${faculty.location!.quickMessage}"',
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Info cards
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      // Contact info card
                      _buildInfoCard(
                        title: 'Contact Information',
                        icon: Icons.contact_mail,
                        children: [
                          _buildInfoRow(
                            Icons.email_outlined,
                            'Email',
                            faculty.user.email,
                          ),
                          if (faculty.user.phoneNumber != null)
                            _buildInfoRow(
                              Icons.phone_outlined,
                              'Phone',
                              faculty.user.phoneNumber!,
                            ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Office hours card
                      if (faculty.user.officeHours != null &&
                          faculty.user.officeHours!.isNotEmpty)
                        _buildInfoCard(
                          title: 'Office Hours',
                          icon: Icons.schedule,
                          children: faculty.user.officeHours!
                              .map(
                                (hours) =>
                                    _buildInfoRow(Icons.access_time, '', hours),
                              )
                              .toList(),
                        ),

                      const SizedBox(height: 16),

                      // Location info (if online)
                      if (faculty.isOnline && faculty.location != null)
                        _buildInfoCard(
                          title: 'Current Location',
                          icon: Icons.location_on,
                          children: [
                            _buildInfoRow(
                              Icons.access_time,
                              'Last Updated',
                              faculty.lastSeenText,
                            ),
                            _buildInfoRow(
                              Icons.gps_fixed,
                              'Status',
                              faculty.location!.isWithinCampus
                                  ? 'Within Campus'
                                  : 'Outside Campus',
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                // Add bottom padding for the floating action bar
                if (faculty.isOnline) const SizedBox(height: 100),

                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
      // Persistent bottom quick-action bar
      bottomNavigationBar: Consumer<FacultyProvider>(
        builder: (context, provider, _) {
          final faculty = provider.getFacultyById(widget.facultyId);

          if (faculty == null || !faculty.isOnline) {
            return const SizedBox.shrink();
          }

          return Container(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Ping / Notify button
                Expanded(
                  child: _ActionButton(
                    icon: Icons.notifications_active_outlined,
                    label: 'Notify',
                    color: AppColors.info,
                    onPressed: () => pingFaculty(
                      context: context,
                      facultyId: faculty.user.id,
                      facultyName: faculty.user.fullName,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Get Directions button
                Expanded(
                  child: _ActionButton(
                    icon: Icons.near_me_outlined,
                    label: 'Directions',
                    color: AppColors.accent,
                    onPressed: () => _navigateToMap(context, faculty),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          if (label.isNotEmpty) ...[
            Text(
              '$label: ',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Navigate to in-app map with faculty location
  void _navigateToMap(BuildContext context, FacultyWithLocation faculty) {
    if (faculty.location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Leader location not available')),
      );
      return;
    }

    // Set focused faculty in provider — the map tab already listens for this
    context.read<FacultyProvider>().setFocusedFaculty(faculty.user.id);

    // Pop back to home screen (which has the map in its IndexedStack)
    // This avoids creating a duplicate StudentMapScreen instance
    Navigator.popUntil(context, (route) => route.isFirst);
  }
}

/// Reusable action button widget with modern design
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, color.withValues(alpha: 0.85)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
