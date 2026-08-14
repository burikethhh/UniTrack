import 'package:flutter/material.dart';
import '../../../models/models.dart';
import '../../../providers/providers.dart';
import '../user_management_screen.dart';
import '../version_management_screen.dart';
import '../live_monitor_screen.dart';
import '../../../core/utils/helpers.dart';

/// Overview Tab - Statistics Cards
class OverviewTab extends StatelessWidget {
  final AdminProvider adminProvider;
  final VoidCallback onBroadcastTap;

  const OverviewTab({
    super.key,
    required this.adminProvider,
    required this.onBroadcastTap,
  });

  @override
  Widget build(BuildContext context) {
    final stats = adminProvider.statistics;
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () => adminProvider.refresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.admin_panel_settings,
                      size: 36,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome, Super Admin',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage users, view statistics, and monitor activity',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Quick Stats Grid
            Text(
              'Quick Statistics',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _StatCard(
                  title: 'Total Users',
                  value: '${stats.totalUsers}',
                  icon: Icons.people,
                  color: Colors.blue,
                  subtitle: '${stats.onlineNow} online now',
                ),
                _StatCard(
                  title: 'Students',
                  value: '${stats.totalStudents}',
                  icon: Icons.school,
                  color: Colors.green,
                  subtitle:
                      '${_percentage(stats.totalStudents, stats.totalUsers)}%',
                ),
                _StatCard(
                  title: 'Student Leaders',
                  value: '${stats.totalStudentLeaders}',
                  icon: Icons.leaderboard,
                  color: Colors.lightGreen,
                  subtitle:
                      '${_percentage(stats.totalStudentLeaders, stats.totalUsers)}%',
                ),
                _StatCard(
                  title: 'Org Officers',
                  value: '${stats.totalOrgOfficers}',
                  icon: Icons.groups,
                  color: Colors.orange,
                  subtitle:
                      '${_percentage(stats.totalOrgOfficers, stats.totalUsers)}%',
                ),
                _StatCard(
                  title: 'Admins',
                  value: '${stats.totalAdmins}',
                  icon: Icons.admin_panel_settings,
                  color: Colors.purple,
                  subtitle: 'Super users',
                ),
                _StatCard(
                  title: 'Active Today',
                  value: '${stats.activeToday}',
                  icon: Icons.trending_up,
                  color: Colors.teal,
                  subtitle: 'Logged in today',
                ),
                _StatCard(
                  title: 'New This Week',
                  value: '${stats.newUsersThisWeek}',
                  icon: Icons.person_add,
                  color: Colors.indigo,
                  subtitle: 'Recent registrations',
                ),
                _StatCard(
                  title: 'New This Month',
                  value: '${stats.newUsersThisMonth}',
                  icon: Icons.calendar_month,
                  color: Colors.pink,
                  subtitle: 'Monthly growth',
                ),
                _StatCard(
                  title: 'Banned Users',
                  value: '${stats.bannedUsers}',
                  icon: Icons.block,
                  color: Colors.red,
                  subtitle: 'Disabled accounts',
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Quick Actions
            Text(
              'Quick Actions',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _ActionCard(
                    title: 'Manage Users',
                    icon: Icons.manage_accounts,
                    color: Colors.blue,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const UserManagementScreen(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionCard(
                    title: 'View Banned',
                    icon: Icons.person_off,
                    color: Colors.red,
                    onTap: () {
                      adminProvider.setShowBannedOnly(true);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const UserManagementScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // App Updates Row
            Row(
              children: [
                Expanded(
                  child: _ActionCard(
                    title: 'App Updates',
                    icon: Icons.system_update,
                    color: Colors.green,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const VersionManagementScreen(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionCard(
                    title: 'Live Monitor',
                    icon: Icons.radar,
                    color: Colors.teal,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LiveMonitorScreen(),
                      ),
                    ),
                  ),
                ), // Live Monitor action
              ],
            ),
            const SizedBox(height: 12),
            _ActionCard(
              title: 'Broadcast Notification',
              icon: Icons.campaign,
              color: Colors.orange,
              onTap: onBroadcastTap,
            ),

            const SizedBox(height: 24),

            // Recent Users
            _RecentUsersSection(users: adminProvider.allUsers.take(5).toList()),
          ],
        ),
      ),
    );
  }

  String _percentage(int part, int total) {
    if (total == 0) return '0';
    return ((part / total) * 100).toStringAsFixed(1);
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
            if (subtitle != null)
              Text(
                subtitle!,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentUsersSection extends StatelessWidget {
  final List<UserModel> users;

  const _RecentUsersSection({required this.users});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Registrations',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (users.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('No users registered yet')),
            ),
          )
        else
          Card(
            child: Column(
              children: users.map((user) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      user.firstName.isNotEmpty
                          ? user.firstName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(user.fullName),
                  subtitle: Text(user.email),
                  trailing: RoleBadge(role: user.role),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
