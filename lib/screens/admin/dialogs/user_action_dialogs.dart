import 'package:flutter/material.dart';
import '../../../models/models.dart';
import '../../../providers/providers.dart';

/// Dialogs for user actions (ban/unban/delete) used by user list tiles.
class UserActionDialogs {
  UserActionDialogs._();

  static void showBanDialog(
    BuildContext context,
    AdminProvider adminProvider,
    UserModel user,
  ) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ban User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to ban ${user.fullName}?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await adminProvider.banUser(
                user.id,
                reason: reasonController.text.isNotEmpty
                    ? reasonController.text
                    : null,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'User banned successfully'
                          : 'Failed to ban user',
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text(
              'Ban User',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    ).then((_) {
      reasonController.dispose();
    });
  }

  static void showUnbanDialog(
    BuildContext context,
    AdminProvider adminProvider,
    UserModel user,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unban User'),
        content: Text('Re-enable account for ${user.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await adminProvider.unbanUser(user.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'User unbanned successfully'
                          : 'Failed to unban user',
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Unban', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  static void showDeleteDialog(
    BuildContext context,
    AdminProvider adminProvider,
    UserModel user,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              'Permanently delete ${user.fullName}?',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'This action cannot be undone!',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await adminProvider.deleteUser(user.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'User deleted permanently'
                          : 'Failed to delete user',
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
