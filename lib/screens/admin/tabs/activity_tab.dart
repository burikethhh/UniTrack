import 'package:flutter/material.dart';
import '../../../providers/providers.dart';
import '../../../core/utils/helpers.dart';

/// Activity Tab - Recent activity logs
class ActivityTab extends StatelessWidget {
  final AdminProvider adminProvider;

  const ActivityTab({super.key, required this.adminProvider});

  @override
  Widget build(BuildContext context) {
    final activities = adminProvider.statistics.recentActivity;
    final theme = Theme.of(context);

    if (activities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No activity recorded yet',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Admin actions will appear here',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final activity = activities[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getActivityColor(activity.action).withAlpha(25),
              child: Icon(
                _getActivityIcon(activity.action),
                color: _getActivityColor(activity.action),
              ),
            ),
            title: Text(
              _formatActionLabel(activity.action),
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('User: ${activity.userName}'),
                if (activity.details != null)
                  Text(
                    activity.details!,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
              ],
            ),
            trailing: Text(
              formatRelativeTime(activity.timestamp),
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ),
        );
      },
    );
  }

  Color _getActivityColor(String action) {
    switch (action) {
      case 'USER_BANNED':
        return Colors.red;
      case 'USER_UNBANNED':
        return Colors.green;
      case 'USER_DELETED':
        return Colors.red.shade900;
      case 'ROLE_CHANGED':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  IconData _getActivityIcon(String action) {
    switch (action) {
      case 'USER_BANNED':
        return Icons.block;
      case 'USER_UNBANNED':
        return Icons.check_circle;
      case 'USER_DELETED':
        return Icons.delete_forever;
      case 'ROLE_CHANGED':
        return Icons.swap_horiz;
      default:
        return Icons.info;
    }
  }

  String _formatActionLabel(String action) {
    switch (action) {
      case 'USER_BANNED':
        return 'User Banned';
      case 'USER_UNBANNED':
        return 'User Unbanned';
      case 'USER_DELETED':
        return 'User Deleted';
      case 'ROLE_CHANGED':
        return 'Role Changed';
      default:
        return action.replaceAll('_', ' ');
    }
  }
}
