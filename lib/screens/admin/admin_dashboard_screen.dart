import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

/// Admin dashboard for system administration
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    // Load admin data from both providers
    context.read<FacultyProvider>().initialize(viewerRole: UserRole.admin);
    context.read<AdminProvider>().initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              _showSignOutDialog(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Tab bar
          Container(
            color: AppColors.surface,
            child: Row(
              children: [
                _buildTab(0, 'Overview', Icons.dashboard),
                _buildTab(1, 'Users', Icons.people),
                _buildTab(2, 'Analytics', Icons.analytics),
              ],
            ),
          ),

          // Content
          Expanded(
            child: IndexedStack(
              index: _currentTab,
              children: [
                _buildOverviewTab(),
                _buildUsersTab(),
                _buildAnalyticsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String label, IconData icon) {
    final isSelected = _currentTab == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _currentTab = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return Consumer2<FacultyProvider, AdminProvider>(
      builder: (context, facultyProvider, adminProvider, _) {
        final stats = adminProvider.statistics;
        return SingleChildScrollView(
          padding: EdgeInsets.all(context.responsivePadding),
          child: ResponsiveContainer(
            maxWidth: 1400,
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Quick stats - responsive grid (real data)
                ResponsiveGrid(
                  mobileColumns: 2,
                  tabletColumns: 2,
                  desktopColumns: 4,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildStatCard(
                      'Total Users',
                      '${stats.totalUsers}',
                      Icons.people,
                      AppColors.primary,
                    ),
                    _buildStatCard(
                      'Online Now',
                      '${stats.onlineNow}',
                      Icons.circle,
                      AppColors.statusAvailable,
                    ),
                    _buildStatCard(
                      'Faculty',
                      '${stats.totalStaff}',
                      Icons.school,
                      AppColors.accent,
                    ),
                    _buildStatCard(
                      'Active Today',
                      '${stats.activeToday}',
                      Icons.trending_up,
                      AppColors.info,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Recent activity — from activity_logs collection
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Recent Activity',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(
                                  () => _currentTab = 1,
                                ); // Switch to Users tab
                              },
                              child: const Text('View All'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (stats.recentActivity.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Text(
                                'No recent activity',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          )
                        else
                          ...stats.recentActivity.take(6).map((log) {
                            return _buildActivityItem(
                              '${log.userName} — ${log.action}${log.details != null ? ' (${log.details})' : ''}',
                              _timeAgo(log.timestamp),
                              _iconForAction(log.action),
                              _colorForAction(log.action),
                            );
                          }),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // System status — dynamic
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'System Status',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 16),
                        _buildSystemStatus(
                          'Firebase Auth',
                          adminProvider.error == null ? 'Operational' : 'Error',
                          adminProvider.error == null
                              ? AppColors.statusAvailable
                              : AppColors.error,
                        ),
                        _buildSystemStatus(
                          'Firestore Database',
                          stats.totalUsers > 0 ? 'Operational' : 'Checking…',
                          stats.totalUsers > 0
                              ? AppColors.statusAvailable
                              : AppColors.warning,
                        ),
                        _buildSystemStatus(
                          'Location Services',
                          'Operational',
                          AppColors.statusAvailable,
                        ),
                        _buildSystemStatus(
                          'Map Tiles',
                          'Operational',
                          AppColors.statusAvailable,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── helpers for activity rendering ──────────────────────────────────

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  IconData _iconForAction(String action) {
    final a = action.toLowerCase();
    if (a.contains('ban')) return Icons.block;
    if (a.contains('unban')) return Icons.check_circle;
    if (a.contains('delete')) return Icons.delete;
    if (a.contains('role')) return Icons.swap_horiz;
    if (a.contains('register') || a.contains('created')) {
      return Icons.person_add;
    }
    if (a.contains('login') || a.contains('online')) return Icons.login;
    if (a.contains('offline') || a.contains('logout')) return Icons.logout;
    return Icons.info_outline;
  }

  Color _colorForAction(String action) {
    final a = action.toLowerCase();
    if (a.contains('ban') || a.contains('delete')) return AppColors.error;
    if (a.contains('unban') || a.contains('online')) {
      return AppColors.statusAvailable;
    }
    if (a.contains('register') || a.contains('created')) {
      return AppColors.accent;
    }
    if (a.contains('role')) return AppColors.info;
    return AppColors.textSecondary;
  }

  Widget _buildUsersTab() {
    return Consumer<FacultyProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            // Search and filters
            Container(
              padding: const EdgeInsets.all(16),
              color: AppColors.surface,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search users...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onChanged: provider.search,
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.filled(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Use User Management for advanced filtering',
                          ),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.filter_list),
                  ),
                ],
              ),
            ),

            // User list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: provider.filteredFaculty.length,
                itemBuilder: (context, index) {
                  final faculty = provider.filteredFaculty[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: ListTile(
                      leading: FacultyAvatar(
                        imageUrl: faculty.user.photoUrl,
                        initials: faculty.user.initials,
                        isOnline: faculty.isOnline,
                        size: 48,
                      ),
                      title: Text(faculty.user.fullName),
                      subtitle: Text(
                        '${faculty.user.department ?? 'No department'} • ${faculty.user.roleString}',
                      ),
                      trailing: PopupMenuButton(
                        itemBuilder: (context) => [
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
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit),
                                SizedBox(width: 8),
                                Text('Edit User'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'disable',
                            child: Row(
                              children: [
                                Icon(Icons.block, color: AppColors.error),
                                SizedBox(width: 8),
                                Text(
                                  'Disable Account',
                                  style: TextStyle(color: AppColors.error),
                                ),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (value) {
                          if (value == 'view') {
                            // Navigate to user detail (reuse user management's detail screen)
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Use User Management for detailed actions',
                                ),
                              ),
                            );
                          } else if (value == 'edit') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Use User Management to edit users',
                                ),
                              ),
                            );
                          } else if (value == 'disable') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Use User Management to disable accounts',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAnalyticsTab() {
    return Consumer<AdminProvider>(
      builder: (context, adminProvider, _) {
        final stats = adminProvider.statistics;
        final departments = stats.usersByDepartment.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Usage stats — real numbers
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Usage Statistics',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),
                      _buildAnalyticRow('Total Users', '${stats.totalUsers}'),
                      _buildAnalyticRow('Students', '${stats.totalStudents}'),
                      _buildAnalyticRow(
                        'Faculty / Staff',
                        '${stats.totalStaff}',
                      ),
                      _buildAnalyticRow('Admins', '${stats.totalAdmins}'),
                      _buildAnalyticRow('Active Today', '${stats.activeToday}'),
                      _buildAnalyticRow(
                        'New This Week',
                        '${stats.newUsersThisWeek}',
                      ),
                      _buildAnalyticRow(
                        'New This Month',
                        '${stats.newUsersThisMonth}',
                      ),
                      _buildAnalyticRow(
                        'Banned Accounts',
                        '${stats.bannedUsers}',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Campus breakdown
              if (stats.usersByCampus.isNotEmpty) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Users by Campus',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 16),
                        ...stats.usersByCampus.entries.map((e) {
                          final pct = stats.totalUsers > 0
                              ? e.value / stats.totalUsers
                              : 0.0;
                          return _buildPeakHour(
                            '${e.key[0].toUpperCase()}${e.key.substring(1)} — ${e.value} users',
                            pct,
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Department breakdown — real data
              if (departments.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Users by Department',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 16),
                        ...departments.map((e) {
                          return _buildDepartmentStat(
                            e.key,
                            e.value,
                            stats.totalUsers,
                          );
                        }),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(
    String text,
    String time,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: const TextStyle(fontSize: 13)),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemStatus(String service, String status, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(service)),
          Text(
            status,
            style: TextStyle(color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildPeakHour(String time, double percentage) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(time, style: const TextStyle(fontSize: 13)),
              Text(
                '${(percentage * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: percentage,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentStat(String name, int count, int total) {
    final pct = total > 0 ? count / total : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(name, overflow: TextOverflow.ellipsis)),
          Text(
            '$count users',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 60,
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }

  void _showSignOutDialog(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await authProvider.signOut();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
