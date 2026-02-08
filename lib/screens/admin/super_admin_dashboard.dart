import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../core/constants/app_constants.dart';
import 'user_management_screen.dart';
import 'user_detail_screen.dart';
import 'version_management_screen.dart';
import 'live_monitor_screen.dart';

/// Super Admin Dashboard with comprehensive user management and statistics
class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _initializeData();
  }

  Future<void> _initializeData() async {
    if (!mounted) return;
    await context.read<AdminProvider>().initialize();
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AuthProvider>(); // Watch for auth changes
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Super Admin Dashboard'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<AdminProvider>().refresh(),
            tooltip: 'Refresh Data',
          ),
          // Logout Button - Clean and Clear
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: OutlinedButton.icon(
              onPressed: () => _showLogoutDialog(context),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Sign Out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade300),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.primary,
          labelColor: Theme.of(context).colorScheme.onPrimaryContainer,
          unselectedLabelColor: Theme.of(context).colorScheme.onPrimaryContainer.withAlpha(153),
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.people), text: 'Users'),
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
            Tab(icon: Icon(Icons.history), text: 'Activity'),
            Tab(icon: Icon(Icons.settings), text: 'System'),
          ],
        ),
      ),
      body: Consumer<AdminProvider>(
        builder: (context, adminProvider, child) {
          if (adminProvider.isLoading && !_isInitialized) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading admin data...'),
                ],
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _OverviewTab(adminProvider: adminProvider),
              _UsersTab(adminProvider: adminProvider),
              _AnalyticsTab(adminProvider: adminProvider),
              _ActivityTab(adminProvider: adminProvider),
              const _SystemTab(),
            ],
          );
        },
      ),
    );
  }
  
  /// Show logout confirmation dialog
  void _showLogoutDialog(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.logout, color: Colors.red.shade700, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Sign Out'),
          ],
        ),
        content: const Text(
          'Are you sure you want to sign out?\n\nYou will need to log in again to access the admin dashboard.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog first
              await authProvider.signOut(); // Then sign out
            },
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Sign Out'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Overview Tab - Statistics Cards
class _OverviewTab extends StatelessWidget {
  final AdminProvider adminProvider;

  const _OverviewTab({required this.adminProvider});

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
                    child: Icon(Icons.admin_panel_settings, size: 36, color: Colors.deepPurple),
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
                  subtitle: '${_percentage(stats.totalStudents, stats.totalUsers)}%',
                ),
                _StatCard(
                  title: 'Staff',
                  value: '${stats.totalStaff}',
                  icon: Icons.work,
                  color: Colors.orange,
                  subtitle: '${_percentage(stats.totalStaff, stats.totalUsers)}%',
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

/// Users Tab - Quick user list with filters
class _UsersTab extends StatelessWidget {
  final AdminProvider adminProvider;

  const _UsersTab({required this.adminProvider});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter Chips
        Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              // Search Bar
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
              
              // Filter Chips Row
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
                      onSelected: (_) => adminProvider.setRoleFilter(UserRole.student),
                      avatar: const Icon(Icons.school, size: 18),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Staff'),
                      selected: adminProvider.roleFilter == UserRole.staff,
                      onSelected: (_) => adminProvider.setRoleFilter(UserRole.staff),
                      avatar: const Icon(Icons.work, size: 18),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Admins'),
                      selected: adminProvider.roleFilter == UserRole.admin,
                      onSelected: (_) => adminProvider.setRoleFilter(UserRole.admin),
                      avatar: const Icon(Icons.admin_panel_settings, size: 18),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Banned'),
                      selected: adminProvider.showBannedOnly,
                      onSelected: adminProvider.setShowBannedOnly,
                      avatar: const Icon(Icons.block, size: 18),
                      backgroundColor: adminProvider.showBannedOnly ? Colors.red.shade100 : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // User Count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${adminProvider.filteredUsers.length} users found',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
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
                      Text(
                        'No users found',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
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
                  itemCount: adminProvider.filteredUsers.length,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemBuilder: (context, index) {
                    final user = adminProvider.filteredUsers[index];
                    return _UserListTile(user: user);
                  },
                ),
        ),
      ],
    );
  }
}

/// Analytics Tab - Charts and detailed statistics
class _AnalyticsTab extends StatelessWidget {
  final AdminProvider adminProvider;

  const _AnalyticsTab({required this.adminProvider});

  @override
  Widget build(BuildContext context) {
    final stats = adminProvider.statistics;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Distribution Pie Chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'User Distribution',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: stats.totalUsers == 0
                        ? const Center(child: Text('No users yet'))
                        : PieChart(
                            PieChartData(
                              sectionsSpace: 3,
                              centerSpaceRadius: 40,
                              sections: [
                                PieChartSectionData(
                                  value: stats.totalStudents.toDouble(),
                                  title: '${stats.totalStudents}',
                                  color: Colors.blue,
                                  radius: 55,
                                  titleStyle: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                PieChartSectionData(
                                  value: stats.totalStaff.toDouble(),
                                  title: '${stats.totalStaff}',
                                  color: Colors.orange,
                                  radius: 55,
                                  titleStyle: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                PieChartSectionData(
                                  value: stats.totalAdmins.toDouble(),
                                  title: '${stats.totalAdmins}',
                                  color: Colors.purple,
                                  radius: 55,
                                  titleStyle: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  // Legend
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ChartLegend(color: Colors.blue, label: 'Students'),
                      const SizedBox(width: 16),
                      _ChartLegend(color: Colors.orange, label: 'Staff'),
                      const SizedBox(width: 16),
                      _ChartLegend(color: Colors.purple, label: 'Admins'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Department Distribution Pie Chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Users by Department',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (stats.usersByDepartment.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No department data available'),
                      ),
                    )
                  else ...[
                    SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 35,
                          sections: stats.usersByDepartment.entries
                              .take(8)
                              .toList()
                              .asMap()
                              .entries
                              .map((e) {
                            final color = Colors.primaries[
                                e.value.key.hashCode % Colors.primaries.length];
                            return PieChartSectionData(
                              value: e.value.value.toDouble(),
                              title: '${e.value.value}',
                              color: color,
                              radius: 50,
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: stats.usersByDepartment.entries
                          .take(8)
                          .map((entry) {
                        final color = Colors.primaries[
                            entry.key.hashCode % Colors.primaries.length];
                        return _ChartLegend(
                          color: color,
                          label: entry.key.length > 20
                              ? '${entry.key.substring(0, 18)}...'
                              : entry.key,
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Users by Campus Bar-style
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Users by Campus',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (stats.usersByCampus.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No campus data available'),
                      ),
                    )
                  else
                    SizedBox(
                      height: 200,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: (stats.usersByCampus.values.isEmpty
                                  ? 1
                                  : stats.usersByCampus.values
                                      .reduce((a, b) => a > b ? a : b))
                              .toDouble() *
                              1.2,
                          barTouchData: BarTouchData(
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                final campus = stats.usersByCampus.keys
                                    .elementAt(group.x.toInt());
                                return BarTooltipItem(
                                  '${_formatCampusName(campus)}\n${rod.toY.toInt()} users',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                );
                              },
                            ),
                          ),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 32,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    value.toInt().toString(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  );
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final idx = value.toInt();
                                  if (idx < 0 || idx >= stats.usersByCampus.length) {
                                    return const SizedBox.shrink();
                                  }
                                  final campus = stats.usersByCampus.keys.elementAt(idx);
                                  final shortName = campus.length > 6
                                      ? '${campus.substring(0, 5)}.'
                                      : campus;
                                  return Text(
                                    shortName,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          gridData: FlGridData(
                            drawVerticalLine: false,
                            horizontalInterval: 5,
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups: stats.usersByCampus.entries
                              .toList()
                              .asMap()
                              .entries
                              .map((e) {
                            final color = Colors.primaries[
                                e.value.key.hashCode % Colors.primaries.length];
                            return BarChartGroupData(
                              x: e.key,
                              barRods: [
                                BarChartRodData(
                                  toY: e.value.value.toDouble(),
                                  color: color,
                                  width: 22,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(6),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Registration Trends - Line chart style
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Activity Overview',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _StatChip(
                          icon: Icons.today,
                          label: 'Active Today',
                          value: '${stats.activeToday}',
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatChip(
                          icon: Icons.wifi,
                          label: 'Online Now',
                          value: '${stats.onlineNow}',
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _StatChip(
                          icon: Icons.date_range,
                          label: 'New This Week',
                          value: '${stats.newUsersThisWeek}',
                          color: Colors.indigo,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatChip(
                          icon: Icons.calendar_month,
                          label: 'New This Month',
                          value: '${stats.newUsersThisMonth}',
                          color: Colors.pink,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
}

/// Activity Tab - Recent activity logs
class _ActivityTab extends StatelessWidget {
  final AdminProvider adminProvider;

  const _ActivityTab({required this.adminProvider});

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
              _formatTime(activity.timestamp),
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

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${time.day}/${time.month}/${time.year}';
  }
}

/// System Tab - Broadcast notifications, data export, system health
class _SystemTab extends StatefulWidget {
  const _SystemTab();

  @override
  State<_SystemTab> createState() => _SystemTabState();
}

class _SystemTabState extends State<_SystemTab> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _isSending = false;
  String _selectedAudience = 'all';
  
  // System stats
  int _totalDocuments = 0;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadSystemStats();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _loadSystemStats() async {
    setState(() => _isLoadingStats = true);
    try {
      final firestore = FirebaseFirestore.instance;
      
      // Count documents in main collections
      final usersCount = await firestore.collection('users').count().get();
      final notificationsCount = await firestore.collection('notifications').count().get();
      final versionsCount = await firestore.collection('app_versions').count().get();
      
      setState(() {
        _totalDocuments = (usersCount.count ?? 0) + 
                          (notificationsCount.count ?? 0) + 
                          (versionsCount.count ?? 0);
        _isLoadingStats = false;
      });
    } catch (e) {
      setState(() => _isLoadingStats = false);
    }
  }

  Future<void> _sendBroadcastNotification() async {
    if (_titleController.text.isEmpty || _bodyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in title and message')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.campaign, color: Colors.orange),
            SizedBox(width: 8),
            Text('Send Broadcast'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Send notification to: ${_getAudienceLabel()}'),
            const SizedBox(height: 12),
            Text('Title: ${_titleController.text}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Message: ${_bodyController.text}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.send),
            label: const Text('Send'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isSending = true);

    try {
      final firestore = FirebaseFirestore.instance;
      
      // Get users based on audience
      Query<Map<String, dynamic>> query = firestore.collection('users');
      if (_selectedAudience == 'students') {
        query = query.where('role', isEqualTo: 'student');
      } else if (_selectedAudience == 'staff') {
        query = query.where('role', isEqualTo: 'staff');
      } else if (_selectedAudience == 'admins') {
        query = query.where('role', isEqualTo: 'admin');
      }

      final users = await query.get();
      int sentCount = 0;
      
      // Firestore batch limit is 500, so chunk if needed
      final chunks = <List<QueryDocumentSnapshot<Map<String, dynamic>>>>[];
      for (var i = 0; i < users.docs.length; i += 400) {
        chunks.add(users.docs.sublist(
          i, i + 400 > users.docs.length ? users.docs.length : i + 400,
        ));
      }

      for (final chunk in chunks) {
        final batch = firestore.batch();
        for (final userDoc in chunk) {
          // Write to top-level 'notifications' collection with correct model fields
          final notifRef = firestore.collection('notifications').doc();
          
          batch.set(notifRef, {
            'senderId': 'system',
            'senderName': 'UniTrack Admin',
            'senderPhotoUrl': null,
            'recipientId': userDoc.id,
            'type': 'system',
            'title': _titleController.text,
            'message': _bodyController.text,
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
            'data': {
              'source': 'admin_broadcast',
              'audience': _selectedAudience,
            },
          });
          sentCount++;
        }
        await batch.commit();
      }

      if (mounted) {
        _titleController.clear();
        _bodyController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Broadcast sent to $sentCount users'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  String _getAudienceLabel() {
    switch (_selectedAudience) {
      case 'students': return 'All Students';
      case 'staff': return 'All Staff';
      case 'admins': return 'All Admins';
      default: return 'All Users';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // System Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'System Information',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SystemInfoRow(
                    icon: Icons.apps,
                    label: 'App Version',
                    value: 'v${AppConstants.appVersion}',
                  ),
                  const Divider(),
                  _SystemInfoRow(
                    icon: Icons.code,
                    label: 'Version Code',
                    value: '${AppConstants.versionCode}',
                  ),
                  const Divider(),
                  _SystemInfoRow(
                    icon: Icons.storage,
                    label: 'Database Documents',
                    value: _isLoadingStats ? 'Loading...' : '$_totalDocuments',
                  ),
                  const Divider(),
                  _SystemInfoRow(
                    icon: Icons.cloud,
                    label: 'Firebase Project',
                    value: 'unitrack-sksu-app',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Broadcast Notification Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.campaign, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        'Broadcast Notification',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Send a notification to all users or specific groups',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  
                  // Audience selector
                  Text('Target Audience', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('All Users'),
                        selected: _selectedAudience == 'all',
                        onSelected: (_) => setState(() => _selectedAudience = 'all'),
                      ),
                      ChoiceChip(
                        label: const Text('Students'),
                        selected: _selectedAudience == 'students',
                        onSelected: (_) => setState(() => _selectedAudience = 'students'),
                      ),
                      ChoiceChip(
                        label: const Text('Staff'),
                        selected: _selectedAudience == 'staff',
                        onSelected: (_) => setState(() => _selectedAudience = 'staff'),
                      ),
                      ChoiceChip(
                        label: const Text('Admins'),
                        selected: _selectedAudience == 'admins',
                        onSelected: (_) => setState(() => _selectedAudience = 'admins'),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Notification Title',
                      hintText: 'e.g., Important Announcement',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.title),
                    ),
                    maxLength: 50,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _bodyController,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      hintText: 'Enter your message here...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.message),
                    ),
                    maxLines: 3,
                    maxLength: 200,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSending ? null : _sendBroadcastNotification,
                      icon: _isSending 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      label: Text(_isSending ? 'Sending...' : 'Send Broadcast'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
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
                  Row(
                    children: [
                      Icon(Icons.flash_on, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Quick Actions',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _QuickActionButton(
                        icon: Icons.system_update,
                        label: 'App Versions',
                        color: Colors.green,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const VersionManagementScreen(),
                          ),
                        ),
                      ),
                      _QuickActionButton(
                        icon: Icons.refresh,
                        label: 'Refresh Stats',
                        color: Colors.blue,
                        onTap: () {
                          _loadSystemStats();
                          context.read<AdminProvider>().refresh();
                        },
                      ),
                      _QuickActionButton(
                        icon: Icons.cleaning_services,
                        label: 'Clear Cache',
                        color: Colors.purple,
                        onTap: () async {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Cache cleared')),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Build Info
          Card(
            color: Colors.grey.shade100,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.build, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        'Build Configuration',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Platform: Android\n'
                    'Architecture: arm64-v8a / x86_64\n'
                    'Minification: Disabled\n'
                    'Firebase: Enabled',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SystemInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withAlpha(25),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== Widget Components =====================

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
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
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
            _RoleBadge(role: user.role),
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
          MaterialPageRoute(
            builder: (_) => UserDetailScreen(userId: user.id),
          ),
        ),
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

  void _handleAction(BuildContext context, String action) {
    final adminProvider = context.read<AdminProvider>();

    switch (action) {
      case 'view':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserDetailScreen(userId: user.id),
          ),
        );
        break;
      case 'ban':
        _showBanDialog(context, adminProvider);
        break;
      case 'unban':
        _showUnbanDialog(context, adminProvider);
        break;
      case 'delete':
        _showDeleteDialog(context, adminProvider);
        break;
    }
  }

  void _showBanDialog(BuildContext context, AdminProvider adminProvider) {
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
                reason: reasonController.text.isNotEmpty ? reasonController.text : null,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? 'User banned successfully' : 'Failed to ban user',
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Ban User', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showUnbanDialog(BuildContext context, AdminProvider adminProvider) {
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
                      success ? 'User unbanned successfully' : 'Failed to unban user',
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

  void _showDeleteDialog(BuildContext context, AdminProvider adminProvider) {
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
                      success ? 'User deleted permanently' : 'Failed to delete user',
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

class _RoleBadge extends StatelessWidget {
  final UserRole role;

  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(127)),
      ),
      child: Text(
        role.name.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
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
                      user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : '?',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(user.fullName),
                  subtitle: Text(user.email),
                  trailing: _RoleBadge(role: user.role),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

class _ChartLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _ChartLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
