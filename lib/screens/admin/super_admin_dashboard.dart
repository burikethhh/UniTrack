import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import 'tabs/overview_tab.dart';
import 'tabs/users_tab.dart';
import 'tabs/analytics_tab.dart';
import 'tabs/activity_tab.dart';
import 'tabs/system_tab.dart';
import 'dialogs/logout_dialog.dart';
import 'dialogs/broadcast_dialog.dart';
import '../../../widgets/common/auth_guards.dart';

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
  bool _isNotAdmin = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _checkAdminRole();
  }

  void _checkAdminRole() {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;
    if (user != null && user.isAdmin && user.isActive) {
      _initializeData();
    } else if (user != null) {
      // User exists but is not admin or not active
      _isNotAdmin = true;
    }
    // If user is null, wait for auth to load (don't set _isNotAdmin yet)
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

  void _showBroadcastDialog() {
    BroadcastDialog.show(context);
  }

  @override
  Widget build(BuildContext context) {
    return AdminGuard(
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isNotAdmin) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    // Auth changes handled by AuthWrapper, no need for watch here

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
              onPressed: () => LogoutDialog.show(context),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Sign Out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade300),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.primary,
          labelColor: Theme.of(context).colorScheme.onPrimaryContainer,
          unselectedLabelColor: Theme.of(
            context,
          ).colorScheme.onPrimaryContainer.withAlpha(153),
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
              OverviewTab(
                adminProvider: adminProvider,
                onBroadcastTap: _showBroadcastDialog,
              ),
              UsersTab(adminProvider: adminProvider),
              AnalyticsTab(adminProvider: adminProvider),
              ActivityTab(adminProvider: adminProvider),
              const SystemTab(),
            ],
          );
        },
      ),
    );
  }
}
