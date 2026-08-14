import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/activity_log_service.dart';
import '../theme/app_colors.dart';
import '../constants/app_constants.dart';
import 'package:provider/provider.dart';

/// Format a campus ID into a displayable campus name.
/// Uses AppConstants.campusesData as the single source of truth.
String formatCampusName(String campusId) {
  final campus = AppConstants.getCampusById(campusId);
  if (campus != null) return campus['name'] as String;
  // Fallback: capitalize the ID
  if (campusId.isEmpty) return 'Unknown Campus';
  return '${campusId[0].toUpperCase()}${campusId.substring(1)} Campus';
}

/// Format a DateTime into a relative time string (e.g., "Just now", "5m ago").
String formatRelativeTime(DateTime time) {
  final now = DateTime.now();
  final diff = now.difference(time);

  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${time.day}/${time.month}/${time.year}';
}

/// Send a "looking for you" ping notification to a student leader / org officer.
/// Shows a confirmation dialog, sends the notification, and displays result feedback.
Future<void> pingFaculty({
  required BuildContext context,
  required String facultyId,
  required String facultyName,
}) async {
  final authProvider = context.read<AuthProvider>();
  final notificationProvider = context.read<NotificationProvider>();

  final currentUser = authProvider.user;
  if (currentUser == null) return;

  // Show confirmation dialog
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.notifications_active,
              color: AppColors.info,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Notify Student Leader', overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
      content: Text(
        'Send a notification to $facultyName that you\'re looking for them?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(dialogContext, true),
          icon: const Icon(Icons.send, size: 18),
          label: const Text('Send'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.info,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  ActivityLogService().logPing(facultyId);

  try {
    final success = await notificationProvider.pingStaff(
      student: currentUser,
      recipientId: facultyId,
      recipientName: facultyName,
    );

    if (!success && context.mounted) {
      if (notificationProvider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(notificationProvider.error!)),
              ],
            ),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
          ),
        );
        notificationProvider.clearError();
        return;
      }
    }

    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('Notification sent to $facultyName'),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(e.toString())),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

/// Reusable role badge widget used across admin screens.
class RoleBadge extends StatelessWidget {
  final UserRole role;
  final bool large;

  const RoleBadge({super.key, required this.role, this.large = false});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String label;

    switch (role) {
      case UserRole.admin:
        color = Colors.purple;
        icon = Icons.admin_panel_settings;
        label = 'Admin';
      case UserRole.organizationOfficer:
        color = Colors.teal;
        icon = Icons.groups;
        label = 'Org Officer';
      case UserRole.studentLeader:
        color = Colors.orange;
        icon = Icons.account_balance;
        label = 'Leader';
      case UserRole.student:
        color = Colors.green;
        icon = Icons.school;
        label = 'Student';
    }

    if (large) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
