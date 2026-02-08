import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
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
    _loadData();
  }
  
  Future<void> _loadData() async {
    // Load admin data
    context.read<FacultyProvider>().initialize();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
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
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
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
    return Consumer<FacultyProvider>(
      builder: (context, facultyProvider, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Quick stats
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total Users',
                      '${facultyProvider.allFaculty.length + 50}', // Mock total
                      Icons.people,
                      AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Online Now',
                      '${facultyProvider.onlineFaculty}',
                      Icons.circle,
                      AppColors.statusAvailable,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Faculty',
                      '${facultyProvider.allFaculty.length}',
                      Icons.school,
                      AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Departments',
                      '${facultyProvider.departments.length}',
                      Icons.business,
                      AppColors.info,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Recent activity
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
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              // View all activity
                            },
                            child: const Text('View All'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildActivityItem(
                        'Dr. Maria Santos went online',
                        '2 min ago',
                        Icons.person,
                        AppColors.statusAvailable,
                      ),
                      _buildActivityItem(
                        'Prof. Juan Dela Cruz updated status',
                        '5 min ago',
                        Icons.update,
                        AppColors.info,
                      ),
                      _buildActivityItem(
                        'New student registered',
                        '15 min ago',
                        Icons.person_add,
                        AppColors.accent,
                      ),
                      _buildActivityItem(
                        'Dr. Ana Garcia went offline',
                        '30 min ago',
                        Icons.person_off,
                        AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // System status
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'System Status',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSystemStatus(
                        'Firebase Auth',
                        'Operational',
                        AppColors.statusAvailable,
                      ),
                      _buildSystemStatus(
                        'Firestore Database',
                        'Operational',
                        AppColors.statusAvailable,
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
        );
      },
    );
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
                      // Show filter dialog
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
                          // Handle action
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Time period selector
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'Time Period:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: const Text('Today'),
                    selected: true,
                    onSelected: (_) {},
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Week'),
                    selected: false,
                    onSelected: (_) {},
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Month'),
                    selected: false,
                    onSelected: (_) {},
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Usage stats
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Usage Statistics',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildAnalyticRow('Total App Opens', '234'),
                  _buildAnalyticRow('Unique Users', '89'),
                  _buildAnalyticRow('Faculty Searches', '156'),
                  _buildAnalyticRow('Navigation Requests', '45'),
                  _buildAnalyticRow('Average Session', '4.2 min'),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Popular times
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Peak Hours',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildPeakHour('8:00 AM - 9:00 AM', 0.8),
                  _buildPeakHour('10:00 AM - 11:00 AM', 0.6),
                  _buildPeakHour('1:00 PM - 2:00 PM', 0.9),
                  _buildPeakHour('3:00 PM - 4:00 PM', 0.5),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Department activity
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Department Activity',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDepartmentStat('IT Department', 12, 8),
                  _buildDepartmentStat('Engineering', 15, 10),
                  _buildDepartmentStat('Business Admin', 8, 5),
                  _buildDepartmentStat('Education', 10, 6),
                ],
              ),
            ),
          ),
        ],
      ),
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
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
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
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
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
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
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
  
  Widget _buildDepartmentStat(String name, int total, int online) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(name)),
          Text(
            '$online/$total online',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 60,
            child: LinearProgressIndicator(
              value: online / total,
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
