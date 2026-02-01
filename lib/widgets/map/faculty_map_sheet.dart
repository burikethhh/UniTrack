import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../models/models.dart';
import '../common/user_avatar.dart';
import '../common/status_badge.dart';

/// Bottom sheet for faculty details on map
class FacultyMapBottomSheet extends StatelessWidget {
  final FacultyWithLocation faculty;
  final String? distanceText;
  final String? walkingTimeText;
  final VoidCallback? onNavigate;
  final VoidCallback? onClose;
  final VoidCallback? onPing;
  
  const FacultyMapBottomSheet({
    super.key,
    required this.faculty,
    this.distanceText,
    this.walkingTimeText,
    this.onNavigate,
    this.onClose,
    this.onPing,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 20,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          
          // Faculty info row
          Row(
            children: [
              FacultyAvatar(
                imageUrl: faculty.user.photoUrl,
                initials: faculty.user.initials,
                isOnline: faculty.isOnline,
                size: 64,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      faculty.user.fullName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (faculty.user.position != null)
                      Text(
                        faculty.user.position!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    if (faculty.user.department != null)
                      Text(
                        faculty.user.department!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    // Campus badge
                    const SizedBox(height: 6),
                    _buildCampusBadge(faculty.user.campusId),
                  ],
                ),
              ),
              if (onClose != null)
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: onClose,
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Status
          Row(
            children: [
              StatusBadge(status: faculty.displayStatus, fontSize: 13),
              const SizedBox(width: 8),
              Text(
                'Last seen: ${faculty.lastSeenText}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          
          // Quick message
          if (faculty.location?.quickMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.message, size: 18, color: AppColors.info),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '"${faculty.location!.quickMessage}"',
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: AppColors.info,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Distance info
          if (distanceText != null || walkingTimeText != null) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (distanceText != null)
                  _buildInfoItem(
                    icon: Icons.straighten,
                    label: 'Distance',
                    value: distanceText!,
                  ),
                if (walkingTimeText != null)
                  _buildInfoItem(
                    icon: Icons.directions_walk,
                    label: 'Walking Time',
                    value: walkingTimeText!,
                  ),
              ],
            ),
          ],
          
          // Action buttons
          if (onNavigate != null && faculty.isOnline) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                // Ping button
                if (onPing != null)
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.notifications_active_outlined,
                      label: 'Notify',
                      color: AppColors.info,
                      onPressed: onPing!,
                    ),
                  ),
                if (onPing != null) const SizedBox(width: 12),
                // Navigate button
                Expanded(
                  child: _ActionButton(
                    icon: Icons.near_me_outlined,
                    label: 'Directions',
                    color: AppColors.accent,
                    onPressed: onNavigate!,
                  ),
                ),
              ],
            ),
          ],
          
          // Safe area padding
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
  
  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
  
  /// Build campus badge with color coding
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_city,
            size: 14,
            color: badgeColor,
          ),
          const SizedBox(width: 4),
          Text(
            campusName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
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
              colors: [
                color,
                color.withValues(alpha: 0.85),
              ],
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
