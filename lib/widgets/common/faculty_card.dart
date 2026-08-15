import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final bool showQuickActions;

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
    final theme = Theme.of(context);
    final primaryTextColor =
        theme.textTheme.titleMedium?.color ?? theme.colorScheme.onSurface;
    final secondaryTextColor = theme.textTheme.bodySmall?.color ??
        theme.colorScheme.onSurface.withValues(alpha: 0.7);

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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 2),

                    // Position & Department
                    if (faculty.user.position != null ||
                        faculty.user.department != null)
                      Text(
                        [
                          faculty.user.position,
                          faculty.user.department,
                        ].where((e) => e != null).join(' • '),
                        style: TextStyle(
                          fontSize: 13,
                          color: secondaryTextColor,
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
                        // On/Off Campus badge
                        _buildOnOffCampusBadge(context, faculty.isWithinCampus),
                        // Campus badge
                        _buildCampusBadge(context, faculty.user.campusId),
                        // Reconnecting indicator (location age 60s–180s)
                        if (faculty.isReconnecting)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.sync,
                                size: 12,
                                color: AppColors.warning,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                faculty.lastSeenText,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.warning,
                                ),
                              ),
                            ],
                          ),
                        // Low accuracy indicator
                        if (faculty.isOnline && faculty.isLowAccuracy)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.gps_not_fixed,
                                size: 12,
                                color: AppColors.warning,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '~${faculty.locationAccuracy?.toStringAsFixed(0)}m',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.warning,
                                ),
                              ),
                            ],
                          ),
                        if (faculty.isOnline && !faculty.isReconnecting)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 12,
                                color: secondaryTextColor,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                faculty.lastSeenText,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: secondaryTextColor,
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
                                color: secondaryTextColor,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                distanceText!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: secondaryTextColor,
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
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

                    // Office Hours (compact, first slot only)
                    if (faculty.user.officeHours != null &&
                        faculty.user.officeHours!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 12,
                            color: secondaryTextColor,
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              faculty.user.officeHours!.length == 1
                                  ? faculty.user.officeHours!.first
                                  : '${faculty.user.officeHours!.first} (+${faculty.user.officeHours!.length - 1} more)',
                              style: TextStyle(
                                fontSize: 11,
                                color: secondaryTextColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Quick Actions Row (Call / Email)
                    if (showQuickActions &&
                        (faculty.user.phoneNumber != null ||
                            faculty.user.email.isNotEmpty)) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (faculty.user.email.isNotEmpty)
                            _buildQuickActionChip(
                              icon: Icons.email_outlined,
                              label: 'Email',
                              color: AppColors.primary,
                              onTap: () => _launchEmail(context, faculty.user.email),
                            ),
                          if (faculty.user.email.isNotEmpty &&
                              faculty.user.phoneNumber != null)
                            const SizedBox(width: 8),
                          if (faculty.user.phoneNumber != null)
                            _buildQuickActionChip(
                              icon: Icons.phone_outlined,
                              label: 'Call',
                              color: AppColors.success,
                              onTap: () =>
                                  _launchPhone(context, faculty.user.phoneNumber!),
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
                        tooltip: 'Looking for You',
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
            child: Icon(icon, color: color, size: 22),
          ),
        ),
      ),
    );
  }

  /// Build on/off campus badge
  Widget _buildOnOffCampusBadge(BuildContext context, bool isWithinCampus) {
    final isOnCampus = isWithinCampus;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isOnCampus ? AppColors.success : AppColors.warning;
    final badgeColor = isDark
        ? Color.lerp(baseColor, Colors.white, 0.35)!
        : baseColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: isDark ? 0.22 : 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isOnCampus ? 'On Campus' : 'Off Campus',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: badgeColor,
        ),
      ),
    );
  }

  /// Build compact campus badge
  Widget _buildCampusBadge(BuildContext context, String campusId) {
    final campus = AppConstants.getCampusById(campusId);
    final campusName = campus?['shortName'] ?? 'Unknown';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Campus-specific colors — all 7 SKSU campuses
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
      case 'bagumbayan':
        badgeColor = Colors.teal;
        break;
      case 'palimbang':
        badgeColor = Colors.indigo;
        break;
      case 'kalamansig':
        badgeColor = Colors.blue;
        break;
      case 'lutayan':
        badgeColor = Colors.brown;
        break;
      default:
        badgeColor = Colors.grey;
    }

    if (isDark) {
      badgeColor = Color.lerp(badgeColor, Colors.white, 0.35)!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: isDark ? 0.22 : 0.15),
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

  /// Launch email app with web fallback and copy feedback
  Future<void> _launchEmail(BuildContext context, String email) async {
    final Uri emailUri = Uri(scheme: 'mailto', path: email);
    try {
      if (kIsWeb) {
        await launchUrl(emailUri);
      } else if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        await Clipboard.setData(ClipboardData(text: email));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Email copied to clipboard: $email'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: email));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Email copied to clipboard: $email'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Launch phone dialer with web fallback and copy feedback
  Future<void> _launchPhone(BuildContext context, String phone) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phone);
    try {
      if (kIsWeb) {
        await Clipboard.setData(ClipboardData(text: phone));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Phone number copied to clipboard: $phone'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        await Clipboard.setData(ClipboardData(text: phone));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Phone number copied to clipboard: $phone'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: phone));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Phone number copied to clipboard: $phone'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
