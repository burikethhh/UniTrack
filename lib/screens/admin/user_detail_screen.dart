import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';

/// Detailed user profile screen for admin management
class UserDetailScreen extends StatefulWidget {
  final String userId;

  const UserDetailScreen({super.key, required this.userId});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  UserModel? _user;
  Map<String, dynamic>? _additionalData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Use postFrameCallback to safely access context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserDetails();
    });
  }

  Future<void> _loadUserDetails() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Try to get from provider first
      final adminProvider = context.read<AdminProvider>();
      _user = adminProvider.getUserById(widget.userId);

      // If not found in provider, fetch from Firestore
      if (_user == null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .get();

        if (doc.exists) {
          _user = UserModel.fromFirestore(doc);
        }
      }

      // Get additional data (ban info, etc.)
      if (_user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .get();
        _additionalData = doc.data();
      }

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Details'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
        actions: [
          if (_user != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: _handleAction,
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh),
                      SizedBox(width: 8),
                      Text('Refresh'),
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
                  value: _user!.isActive ? 'ban' : 'unban',
                  child: Row(
                    children: [
                      Icon(
                        _user!.isActive ? Icons.block : Icons.check_circle,
                        color: _user!.isActive ? Colors.orange : Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Text(_user!.isActive ? 'Ban User' : 'Unban User'),
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
                      Text('Delete User', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading user details...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              onPressed: _loadUserDetails,
            ),
          ],
        ),
      );
    }

    if (_user == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('User not found'),
          ],
        ),
      );
    }

    final user = _user!;
    final isActive = user.isActive;

    return RefreshIndicator(
      onRefresh: _loadUserDetails,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Avatar and Status
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: _getRoleColor(user.role).withAlpha(25),
                          child: user.photoUrl != null
                              ? ClipOval(
                                  child: Image.network(
                                    user.photoUrl!,
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => _buildInitials(user),
                                  ),
                                )
                              : _buildInitials(user),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isActive ? Colors.green : Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: Icon(
                              isActive ? Icons.check : Icons.block,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Name
                    Text(
                      user.fullName,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        decoration: isActive ? null : TextDecoration.lineThrough,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),

                    // Email
                    Text(
                      user.email,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Role Badge
                    _RoleBadgeLarge(role: user.role),

                    // Status Badge
                    if (!isActive) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.block, size: 16, color: Colors.red.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'ACCOUNT BANNED',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // User Information Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User Information',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    _InfoRow(
                      icon: Icons.badge,
                      label: 'User ID',
                      value: user.id,
                    ),
                    _InfoRow(
                      icon: Icons.person,
                      label: 'First Name',
                      value: user.firstName,
                    ),
                    _InfoRow(
                      icon: Icons.person,
                      label: 'Last Name',
                      value: user.lastName,
                    ),
                    _InfoRow(
                      icon: Icons.email,
                      label: 'Email',
                      value: user.email,
                    ),
                    if (user.phoneNumber != null)
                      _InfoRow(
                        icon: Icons.phone,
                        label: 'Phone',
                        value: user.phoneNumber!,
                      ),
                    _InfoRow(
                      icon: Icons.security,
                      label: 'Role',
                      value: user.role.name.toUpperCase(),
                      valueColor: _getRoleColor(user.role),
                    ),
                    _InfoRow(
                      icon: Icons.location_city,
                      label: 'Campus',
                      value: _formatCampusName(user.campusId),
                    ),
                    if (user.department != null)
                      _InfoRow(
                        icon: Icons.business,
                        label: 'Department',
                        value: user.department!,
                      ),
                    if (user.position != null)
                      _InfoRow(
                        icon: Icons.work,
                        label: 'Position',
                        value: user.position!,
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Account Information Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account Information',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    _InfoRow(
                      icon: Icons.calendar_today,
                      label: 'Registered',
                      value: _formatDateTime(user.createdAt),
                    ),
                    if (user.lastLoginAt != null)
                      _InfoRow(
                        icon: Icons.login,
                        label: 'Last Login',
                        value: _formatDateTime(user.lastLoginAt!),
                      ),
                    _InfoRow(
                      icon: isActive ? Icons.check_circle : Icons.block,
                      label: 'Status',
                      value: isActive ? 'Active' : 'Banned',
                      valueColor: isActive ? Colors.green : Colors.red,
                    ),
                    if (_additionalData?['bannedAt'] != null) ...[
                      _InfoRow(
                        icon: Icons.event_busy,
                        label: 'Banned At',
                        value: _formatDateTime(
                          (_additionalData!['bannedAt'] as Timestamp).toDate(),
                        ),
                      ),
                      if (_additionalData?['banReason'] != null)
                        _InfoRow(
                          icon: Icons.info,
                          label: 'Ban Reason',
                          value: _additionalData!['banReason'],
                        ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Quick Actions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Actions',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ActionButton(
                          icon: Icons.swap_horiz,
                          label: 'Change Role',
                          color: Colors.blue,
                          onPressed: () => _handleAction('role'),
                        ),
                        _ActionButton(
                          icon: isActive ? Icons.block : Icons.check_circle,
                          label: isActive ? 'Ban User' : 'Unban User',
                          color: isActive ? Colors.orange : Colors.green,
                          onPressed: () =>
                              _handleAction(isActive ? 'ban' : 'unban'),
                        ),
                        _ActionButton(
                          icon: Icons.delete_forever,
                          label: 'Delete User',
                          color: Colors.red,
                          onPressed: () => _handleAction('delete'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildInitials(UserModel user) {
    return Text(
      user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : '?',
      style: TextStyle(
        fontSize: 40,
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

  String _formatCampusName(String campusId) {
    switch (campusId) {
      case 'access':
        return 'ACCESS Campus';
      case 'main':
        return 'Main Campus';
      case 'tacurong':
        return 'Tacurong Campus';
      case 'isulan':
        return 'Isulan Campus';
      case 'kalamansig':
        return 'Kalamansig Campus';
      case 'lutayan':
        return 'Lutayan Campus';
      case 'palimbang':
        return 'Palimbang Campus';
      case 'bagumbayan':
        return 'Bagumbayan Campus';
      default:
        return campusId.toUpperCase();
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    String timeStr;
    if (diff.inMinutes < 1) {
      timeStr = 'Just now';
    } else if (diff.inMinutes < 60) {
      timeStr = '${diff.inMinutes} minutes ago';
    } else if (diff.inHours < 24) {
      timeStr = '${diff.inHours} hours ago';
    } else if (diff.inDays < 7) {
      timeStr = '${diff.inDays} days ago';
    } else {
      timeStr = '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }

    return '$timeStr\n(${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')})';
  }

  void _handleAction(String action) {
    if (_user == null) return;
    final adminProvider = context.read<AdminProvider>();

    switch (action) {
      case 'refresh':
        _loadUserDetails();
        break;
      case 'role':
        _showRoleDialog(adminProvider);
        break;
      case 'ban':
        _showBanDialog(adminProvider);
        break;
      case 'unban':
        _showUnbanDialog(adminProvider);
        break;
      case 'delete':
        _showDeleteDialog(adminProvider);
        break;
    }
  }

  void _showRoleDialog(AdminProvider adminProvider) {
    UserRole selectedRole = _user!.role;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          icon: const Icon(Icons.swap_horiz, color: Colors.blue, size: 48),
          title: const Text('Change User Role'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: UserRole.values
                .map((role) => RadioListTile<UserRole>(
                      title: Text(role.name.toUpperCase()),
                      value: role,
                      groupValue: selectedRole, // ignore: deprecated_member_use
                      onChanged: (value) { // ignore: deprecated_member_use
                        if (value != null) {
                          setState(() => selectedRole = value);
                        }
                      },
                    ))
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedRole == _user!.role
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      final success = await adminProvider.updateUserRole(
                        _user!.id,
                        selectedRole,
                      );
                      if (!mounted) return;
                      if (success) {
                        await _loadUserDetails();
                      }
                      _showResult(success, 'Role updated', 'Failed to update role');
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBanDialog(AdminProvider adminProvider) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.block, color: Colors.red, size: 48),
        title: const Text('Ban User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Ban ${_user!.fullName}?'),
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
                _user!.id,
                reason: reasonController.text.isNotEmpty
                    ? reasonController.text
                    : null,
              );
              if (!mounted) return;
              if (success) {
                await _loadUserDetails();
              }
              _showResult(success, 'User banned', 'Failed to ban user');
            },
            child: const Text('Ban', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showUnbanDialog(AdminProvider adminProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
        title: const Text('Unban User'),
        content: Text('Re-enable ${_user!.fullName}\'s account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await adminProvider.unbanUser(_user!.id);
              if (!mounted) return;
              if (success) {
                await _loadUserDetails();
              }
              _showResult(success, 'User unbanned', 'Failed to unban user');
            },
            child: const Text('Unban', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(AdminProvider adminProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_forever, color: Colors.red, size: 48),
        title: const Text('Delete User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Permanently delete ${_user!.fullName}?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.red),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This cannot be undone!',
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
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await adminProvider.deleteUser(_user!.id);
              _showResult(success, 'User deleted', 'Failed to delete user');
              if (success && mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showResult(bool success, String successMsg, String failMsg) {
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
        ),
      );
    }
  }
}

// ===================== Widget Components =====================

class _RoleBadgeLarge extends StatelessWidget {
  final UserRole role;

  const _RoleBadgeLarge({required this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _getColor().withAlpha(25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getColor()),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getIcon(), color: _getColor()),
          const SizedBox(width: 8),
          Text(
            role.name.toUpperCase(),
            style: TextStyle(
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
    return ElevatedButton.icon(
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withAlpha(25),
        foregroundColor: color,
        elevation: 0,
        side: BorderSide(color: color.withAlpha(127)),
      ),
      onPressed: onPressed,
    );
  }
}
