import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/models.dart';
import '../../../providers/providers.dart';
import '../user_management_screen.dart';
import '../user_detail_screen.dart';
import '../dialogs/user_action_dialogs.dart';
import '../../../core/utils/helpers.dart';

class UsersTab extends StatelessWidget {
  final AdminProvider adminProvider;

  const UsersTab({super.key, required this.adminProvider});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search users...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onChanged: adminProvider.search,
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: adminProvider.roleFilter == null,
                      onSelected: (_) => adminProvider.setRoleFilter(null),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Students'),
                      selected: adminProvider.roleFilter == UserRole.student,
                      onSelected: (_) =>
                          adminProvider.setRoleFilter(UserRole.student),
                      avatar: const Icon(Icons.school, size: 18),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Leaders'),
                      selected: adminProvider.roleFilter == UserRole.studentLeader,
                      onSelected: (_) =>
                          adminProvider.setRoleFilter(UserRole.studentLeader),
                      avatar: const Icon(Icons.star_outline, size: 18),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Officers'),
                      selected: adminProvider.roleFilter == UserRole.organizationOfficer,
                      onSelected: (_) =>
                          adminProvider.setRoleFilter(UserRole.organizationOfficer),
                      avatar: const Icon(Icons.business_center, size: 18),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Admins'),
                      selected: adminProvider.roleFilter == UserRole.admin,
                      onSelected: (_) =>
                          adminProvider.setRoleFilter(UserRole.admin),
                      avatar: const Icon(Icons.admin_panel_settings, size: 18),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Banned'),
                      selected: adminProvider.showBannedOnly,
                      onSelected: adminProvider.setShowBannedOnly,
                      avatar: const Icon(Icons.block, size: 18),
                      backgroundColor: adminProvider.showBannedOnly
                          ? Colors.red.shade100
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Pending Approvals
        Consumer<AdminProvider>(
          builder: (context, provider, _) {
            final pending = provider.pendingApprovalUsers;
            if (pending.isEmpty) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.pending_actions, color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${pending.length} pending approval${pending.length > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade800,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...pending.take(3).map((user) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: user.role == UserRole.studentLeader
                              ? Colors.orange.shade300
                              : Colors.teal.shade300,
                          child: Text(
                            user.firstName[0].toUpperCase(),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                              Text(
                                user.role == UserRole.studentLeader ? 'Student Leader' : 'Organization Officer',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 30,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            onPressed: () {
                              provider.approveUser(user.id).then((ok) {
                                if (ok && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('${user.fullName} approved'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              });
                            },
                            child: const Text('Approve'),
                          ),
                        ),
                      ],
                    ),
                  )),
                  if (pending.length > 3)
                    Text(
                      '+ ${pending.length - 3} more',
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                    ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 8),

        // User Count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${adminProvider.filteredUsers.length} users found',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey.shade600),
              ),
              TextButton.icon(
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('Advanced'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const UserManagementScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),

        // User List
        Expanded(
          child: adminProvider.filteredUsers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('No users found', style: TextStyle(color: Colors.grey.shade600)),
                      if (adminProvider.searchQuery.isNotEmpty ||
                          adminProvider.roleFilter != null ||
                          adminProvider.showBannedOnly)
                        TextButton(
                          onPressed: adminProvider.clearFilters,
                          child: const Text('Clear Filters'),
                        ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: adminProvider.filteredUsers.length + (adminProvider.hasMoreUsers ? 1 : 0),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemBuilder: (context, index) {
                    if (index == adminProvider.filteredUsers.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: adminProvider.isLoading
                              ? const CircularProgressIndicator()
                              : TextButton.icon(
                                  onPressed: adminProvider.loadMoreUsers,
                                  icon: const Icon(Icons.expand_more),
                                  label: const Text('Load More'),
                                ),
                        ),
                      );
                    }
                    final user = adminProvider.filteredUsers[index];
                    return _UserListTile(user: user);
                  },
                ),
        ),
      ],
    );
  }
}

class _UserListTile extends StatelessWidget {
  final UserModel user;

  const _UserListTile({required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = user.isActive;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: _getRoleColor(user.role).withAlpha(25),
              child: Text(
                user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : '?',
                style: TextStyle(
                  color: _getRoleColor(user.role),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (!isActive)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.block, size: 12, color: Colors.white),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user.fullName,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  decoration: isActive ? null : TextDecoration.lineThrough,
                  color: isActive ? null : Colors.grey,
                ),
              ),
            ),
            RoleBadge(role: user.role),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user.email,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? Colors.grey.shade600 : Colors.grey.shade400,
              ),
            ),
            if (user.department != null)
              Text(
                user.department!,
                style: TextStyle(
                  fontSize: 11,
                  color: isActive ? theme.colorScheme.primary : Colors.grey.shade400,
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (action) => _handleAction(context, action),
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'view', child: Text('View Details')),
            PopupMenuItem(
              value: isActive ? 'ban' : 'unban',
              child: Text(isActive ? 'Ban User' : 'Unban User'),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete User', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => UserDetailScreen(userId: user.id)),
        ),
      ),
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.student:
        return Colors.green;
      case UserRole.studentLeader:
        return Colors.orange;
      case UserRole.organizationOfficer:
        return Colors.teal;
      case UserRole.admin:
        return Colors.purple;
    }
  }

  void _handleAction(BuildContext context, String action) {
    final adminProvider = context.read<AdminProvider>();

    switch (action) {
      case 'view':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => UserDetailScreen(userId: user.id)),
        );
        break;
      case 'ban':
        UserActionDialogs.showBanDialog(context, adminProvider, user);
        break;
      case 'unban':
        UserActionDialogs.showUnbanDialog(context, adminProvider, user);
        break;
      case 'delete':
        UserActionDialogs.showDeleteDialog(context, adminProvider, user);
        break;
    }
  }
}