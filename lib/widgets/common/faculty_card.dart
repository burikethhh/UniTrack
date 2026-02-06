import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../models/models.dart';
import 'user_avatar.dart';
import 'status_badge.dart';

/// Faculty list card widget
class FacultyCard extends StatelessWidget {
  final FacultyWithLocation faculty;
  final VoidCallback? onTap;
  final VoidCallback? onNavigate;
  final VoidCallback? onPing;
  final bool showDistance;
  final String? distanceText;
  final bool showQuickActions; // Enable call/email buttons
  
  const FacultyCard({
    super.key,
    required this.faculty,
    this.onTap,
    this.onNavigate,
    this.onPing,
    this.showDistance = false,
    this.distanceText,
    this.showQuickActions = true,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              FacultyAvatar(
                imageUrl: faculty.user.photoUrl,
                initials: faculty.user.initials,
                isOnline: faculty.isOnline,
                size: 56,
              ),
              const SizedBox(width: 16),
              
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      faculty.user.fullName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    
                    // Position & Department
                    if (faculty.user.position != null || faculty.user.department != null)
                      Text(
                        [
                          faculty.user.position,
                          faculty.user.department,
                        ].where((e) => e != null).join(' • '),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 8),
                    
                    // Status row - use Wrap to prevent overflow
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusBadge(status: faculty.displayStatus),
                        // Campus badge
                        _buildCampusBadge(faculty.user.campusId),
                        if (faculty.isOnline)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 12,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                faculty.lastSeenText,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        if (showDistance && distanceText != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.directions_walk,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                distanceText!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    
                    // Quick message
                    if (faculty.location?.quickMessage != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '"${faculty.location!.quickMessage}"',
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: AppColors.info,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    
                    // Quick Actions Row (Call / Email)
                    if (showQuickActions && (faculty.user.phoneNumber != null || faculty.user.email.isNotEmpty)) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (faculty.user.email.isNotEmpty)
                            _buildQuickActionChip(
                              icon: Icons.email_outlined,
                              label: 'Email',
                              color: AppColors.primary,
                              onTap: () => _launchEmail(faculty.user.email),
                            ),
                          if (faculty.user.email.isNotEmpty && faculty.user.phoneNumber != null)
                            const SizedBox(width: 8),
                          if (faculty.user.phoneNumber != null)
                            _buildQuickActionChip(
                              icon: Icons.phone_outlined,
                              label: 'Call',
                              color: AppColors.success,
                              onTap: () => _launchPhone(faculty.user.phoneNumber!),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              
              // Action buttons - vertical column for better mobile UX
              if (faculty.isOnline && (onPing != null || onNavigate != null))
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Ping button
                    if (onPing != null)
                      _buildActionButton(
                        icon: Icons.notifications_active_outlined,
                        color: AppColors.info,
                        onPressed: onPing!,
                        tooltip: 'Notify Teacher',
                      ),
                    if (onPing != null && onNavigate != null)
                      const SizedBox(height: 8),
                    // Navigate button
                    if (onNavigate != null)
                      _buildActionButton(
                        icon: Icons.near_me_outlined,
                        color: AppColors.accent,
                        onPressed: onNavigate!,
                        tooltip: 'Get Directions',
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Build consistent action button
  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: color,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
  
  /// Build compact campus badge
  Widget _buildCampusBadge(String campusId) {
    final campus = AppConstants.getCampusById(campusId);
    final campusName = campus?['shortName'] ?? 'Unknown';
    
    // Campus-specific colors
    Color badgeColor;
    switch (campusId) {
      case 'isulan':
        badgeColor = AppColors.primary;
        break;
      case 'tacurong':
        badgeColor = Colors.orange;
        break;
      case 'access':
        badgeColor = Colors.purple;
        break;
      default:
        badgeColor = Colors.grey;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        campusName,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: badgeColor,
        ),
      ),
    );
  }
  
  /// Build quick action chip (Email/Call)
  Widget _buildQuickActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Launch email app
  Future<void> _launchEmail(String email) async {
    final Uri emailUri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }
  
  /// Launch phone dialer
  Future<void> _launchPhone(String phone) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }
}
