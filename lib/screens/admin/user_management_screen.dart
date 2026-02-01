import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import 'user_detail_screen.dart';

/// Full User Management Screen with advanced filtering and sorting
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _sortBy = 'date';
  bool _sortAscending = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<AdminProvider>().loadAllUsers(),
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort By',
            onSelected: (value) {
              setState(() {
                if (_sortBy == value) {
                  _sortAscending = !_sortAscending;
                } else {
                  _sortBy = value;
                  _sortAscending = true;
                }
              });
              context.read<AdminProvider>().setSortBy(value);
            },
            itemBuilder: (_) => [
              _buildSortMenuItem('name', 'Name'),
              _buildSortMenuItem('date', 'Date Registered'),
              _buildSortMenuItem('role', 'Role'),
              _buildSortMenuItem('campus', 'Campus'),
            ],
          ),
        ],
      ),
      body: Consumer<AdminProvider>(
        builder: (context, adminProvider, child) {
          return Column(
            children: [
              // Search and Filter Section
              Container(
                color: theme.colorScheme.primaryContainer.withAlpha(76),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Search Bar
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by name, email, or department...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  adminProvider.search('');
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                      ),
                      onChanged: adminProvider.search,
                    ),
                    const SizedBox(height: 12),

                    // Filter Row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _FilterChip(
                            label: 'All Users',
                            selected: adminProvider.roleFilter == null &&
                                !adminProvider.showBannedOnly,
                            onSelected: (_) {
                              adminProvider.clearFilters();
                              _searchController.clear();
                            },
                            count: adminProvider.allUsers.length,
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Students',
                            selected: adminProvider.roleFilter == UserRole.student,
                            onSelected: (_) =>
                                adminProvider.setRoleFilter(UserRole.student),
                            count: adminProvider.students.length,
                            icon: Icons.school,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Staff',
                            selected: adminProvider.roleFilter == UserRole.staff,
                            onSelected: (_) =>
                                adminProvider.setRoleFilter(UserRole.staff),
                            count: adminProvider.staff.length,
                            icon: Icons.work,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Admins',
                            selected: adminProvider.roleFilter == UserRole.admin,
                            onSelected: (_) =>
                                adminProvider.setRoleFilter(UserRole.admin),
                            count: adminProvider.admins.length,
                            icon: Icons.admin_panel_settings,
                            color: Colors.purple,
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Banned',
                            selected: adminProvider.showBannedOnly,
                            onSelected: adminProvider.setShowBannedOnly,
                            count: adminProvider.bannedUsers.length,
                            icon: Icons.block,
                            color: Colors.red,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Results Count
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${adminProvider.filteredUsers.length} of ${adminProvider.allUsers.length} users',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (adminProvider.searchQuery.isNotEmpty ||
                        adminProvider.roleFilter != null ||
                        adminProvider.showBannedOnly)
                      TextButton.icon(
                        icon: const Icon(Icons.clear_all, size: 18),
                        label: const Text('Clear Filters'),
                        onPressed: () {
                          adminProvider.clearFilters();
                          _searchController.clear();
                        },
                      ),
                  ],
                ),
              ),

              // User List
              Expanded(
                child: adminProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : adminProvider.filteredUsers.isEmpty
                        ? _EmptyState(
                            hasFilters: adminProvider.searchQuery.isNotEmpty ||
                                adminProvider.roleFilter != null ||
                                adminProvider.showBannedOnly,
                            onClear: () {
                              adminProvider.clearFilters();
                              _searchController.clear();
                            },
                          )
                        : RefreshIndicator(
                            onRefresh: () => adminProvider.loadAllUsers(),
                            child: ListView.builder(
                              itemCount: adminProvider.filteredUsers.length,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              itemBuilder: (context, index) {
                                final user = adminProvider.filteredUsers[index];
                                return _UserCard(
                                  user: user,
                                  onTap: () => _openUserDetail(user),
                                  onAction: (action) =>
                                      _handleUserAction(user, action),
                                );
                              },
                            ),
                          ),
              ),
            ],
          );
        },
      ),
    );
  }

  PopupMenuItem<String> _buildSortMenuItem(String value, String label) {
    final isSelected = _sortBy == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (isSelected)
            Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 16,
            )
          else
            const SizedBox(width: 16),
          const SizedBox(width: 8),
          Text(label),
          if (isSelected)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.check, size: 16),
            ),
        ],
      ),
    );
  }

  void _openUserDetail(UserModel user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserDetailScreen(userId: user.id),
      ),
    );
  }

  void _handleUserAction(UserModel user, String action) {
    final adminProvider = context.read<AdminProvider>();

    switch (action) {
      case 'ban':
        _showBanDialog(user, adminProvider);
        break;
      case 'unban':
        _showUnbanDialog(user, adminProvider);
        break;
      case 'delete':
        _showDeleteDialog(user, adminProvider);
        break;
      case 'role':
        _showRoleDialog(user, adminProvider);
        break;
    }
  }

  void _showBanDialog(UserModel user, AdminProvider adminProvider) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.block, color: Colors.red, size: 48),
        title: const Text('Ban User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ban ${user.fullName} from using the app?',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'They will not be able to log in.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'Enter ban reason...',
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
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.block),
            label: const Text('Ban User'),
            onPressed: () async {
              Navigator.pop(ctx);
              _showLoadingDialog();
              final success = await adminProvider.banUser(
                user.id,
                reason: reasonController.text.isNotEmpty
                    ? reasonController.text
                    : null,
              );
              if (mounted) Navigator.pop(context);
              _showResultSnackbar(success, 'User banned', 'Failed to ban user');
            },
          ),
        ],
      ),
    );
  }

  void _showUnbanDialog(UserModel user, AdminProvider adminProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
        title: const Text('Unban User'),
        content: Text(
          'Re-enable ${user.fullName}\'s account?',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.check),
            label: const Text('Unban'),
            onPressed: () async {
              Navigator.pop(ctx);
              _showLoadingDialog();
              final success = await adminProvider.unbanUser(user.id);
              if (mounted) Navigator.pop(context);
              _showResultSnackbar(
                  success, 'User unbanned', 'Failed to unban user');
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(UserModel user, AdminProvider adminProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_forever, color: Colors.red, size: 48),
        title: const Text('Delete User Permanently'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Delete ${user.fullName}?',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.red),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action is PERMANENT and cannot be undone!',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.delete_forever),
            label: const Text('Delete Forever'),
            onPressed: () async {
              Navigator.pop(ctx);
              _showLoadingDialog();
              final success = await adminProvider.deleteUser(user.id);
              if (mounted) Navigator.pop(context);
              _showResultSnackbar(
                  success, 'User deleted', 'Failed to delete user');
            },
          ),
        ],
      ),
    );
  }

  void _showRoleDialog(UserModel user, AdminProvider adminProvider) {
    UserRole selectedRole = user.role;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          icon: const Icon(Icons.swap_horiz, color: Colors.blue, size: 48),
          title: const Text('Change User Role'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Change role for ${user.fullName}'),
              const SizedBox(height: 16),
              ...UserRole.values.map((role) => RadioListTile<UserRole>(
                    title: Text(role.name.toUpperCase()),
                    subtitle: Text(_getRoleDescription(role)),
                    value: role,
                    groupValue: selectedRole,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => selectedRole = value);
                      }
                    },
                  )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Save'),
              onPressed: selectedRole == user.role
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      _showLoadingDialog();
                      final success = await adminProvider.updateUserRole(
                          user.id, selectedRole);
                      if (mounted) Navigator.pop(context);
                      _showResultSnackbar(
                          success, 'Role updated', 'Failed to update role');
                    },
            ),
          ],
        ),
      ),
    );
  }

  String _getRoleDescription(UserRole role) {
    switch (role) {
      case UserRole.student:
        return 'Regular student access';
      case UserRole.staff:
        return 'Faculty/Staff member';
      case UserRole.admin:
        return 'Full administrative access';
    }
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        ),
      ),
    );
  }

  void _showResultSnackbar(bool success, String successMsg, String failMsg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle : Icons.error,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(success ? successMsg : failMsg),
            ],
          ),
          backgroundColor: success ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// ===================== Widget Components =====================

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Function(bool) onSelected;
  final int count;
  final IconData? icon;
  final Color? color;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    required this.count,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white.withAlpha(76)
                  : Colors.grey.withAlpha(76),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
      avatar: icon != null
          ? Icon(icon, size: 18, color: selected ? Colors.white : color)
          : null,
      selected: selected,
      onSelected: onSelected,
      selectedColor: color ?? Theme.of(context).colorScheme.primary,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? Colors.white : null,
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onTap;
  final Function(String) onAction;

  const _UserCard({
    required this.user,
    required this.onTap,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = user.isActive;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isActive ? 1 : 0,
      color: isActive ? null : Colors.grey.shade100,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Avatar
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: _getRoleColor(user.role).withAlpha(25),
                    child: user.photoUrl != null
                        ? ClipOval(
                            child: Image.network(
                              user.photoUrl!,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _buildInitials(),
                            ),
                          )
                        : _buildInitials(),
                  ),
                  if (!isActive)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.block,
                            size: 12, color: Colors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),

              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.fullName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              decoration:
                                  isActive ? null : TextDecoration.lineThrough,
                              color: isActive ? null : Colors.grey,
                            ),
                          ),
                        ),
                        _RoleBadge(role: user.role),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (user.department != null) ...[
                          Icon(Icons.business,
                              size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              user.department!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        const Spacer(),
                        Icon(Icons.calendar_today,
                            size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(user.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                onSelected: onAction,
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'view',
                    child: Row(
                      children: [
                        Icon(Icons.visibility),
                        SizedBox(width: 8),
                        Text('View Details'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'role',
                    child: Row(
                      children: [
                        Icon(Icons.swap_horiz),
                        SizedBox(width: 8),
                        Text('Change Role'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: isActive ? 'ban' : 'unban',
                    child: Row(
                      children: [
                        Icon(
                          isActive ? Icons.block : Icons.check_circle,
                          color: isActive ? Colors.orange : Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Text(isActive ? 'Ban User' : 'Unban User'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_forever, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete User',
                            style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInitials() {
    return Text(
      user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : '?',
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: _getRoleColor(user.role),
      ),
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.student:
        return Colors.green;
      case UserRole.staff:
        return Colors.orange;
      case UserRole.admin:
        return Colors.purple;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _RoleBadge extends StatelessWidget {
  final UserRole role;

  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getColor().withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getColor().withAlpha(127)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getIcon(), size: 12, color: _getColor()),
          const SizedBox(width: 4),
          Text(
            role.name.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: _getColor(),
            ),
          ),
        ],
      ),
    );
  }

  Color _getColor() {
    switch (role) {
      case UserRole.student:
        return Colors.green;
      case UserRole.staff:
        return Colors.orange;
      case UserRole.admin:
        return Colors.purple;
    }
  }

  IconData _getIcon() {
    switch (role) {
      case UserRole.student:
        return Icons.school;
      case UserRole.staff:
        return Icons.work;
      case UserRole.admin:
        return Icons.admin_panel_settings;
    }
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback onClear;

  const _EmptyState({required this.hasFilters, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasFilters ? Icons.search_off : Icons.people_outline,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters ? 'No users match your filters' : 'No users found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasFilters
                ? 'Try adjusting your search or filters'
                : 'Users will appear here once registered',
            style: TextStyle(
              color: Colors.grey.shade500,
            ),
          ),
          if (hasFilters) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear All Filters'),
              onPressed: onClear,
            ),
          ],
        ],
      ),
    );
  }
}
