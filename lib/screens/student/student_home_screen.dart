import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import 'student_directory_screen.dart';
import 'student_map_screen.dart';
import 'student_profile_screen.dart';
import '../staff_leader/tracking_dashboard_screen.dart';

/// Main screen for student module with adaptive navigation
class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  int _currentIndex = 0;
  bool _lastIsStaff = false;

  @override
  void initState() {
    super.initState();

    // Initialize faculty provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final viewerRole = authProvider.user?.role ?? UserRole.student;
      context.read<FacultyProvider>().initialize(
        viewerRole: viewerRole,
        viewerCampusId: authProvider.user?.campusId,
      );
      // Initialize location provider for student location sharing
      if (authProvider.user != null) {
        context.read<LocationProvider>().initialize(
          authProvider.user!.id,
          campusId: authProvider.user!.campusId,
        );
      }

      // Listen for focused faculty changes (e.g. from faculty detail "Navigate to Map")
      // and switch to map tab automatically
      context.read<FacultyProvider>().addListener(_onFacultyProviderChanged);
    });
  }

  @override
  void dispose() {
    // Remove listener safely — provider may already be disposed if app is shutting down
    try {
      context.read<FacultyProvider>().removeListener(_onFacultyProviderChanged);
    } catch (_) {}
    super.dispose();
  }

  void _onFacultyProviderChanged() {
    if (!mounted) return;
    final focusedId = context.read<FacultyProvider>().focusedFacultyId;
    if (focusedId != null && _currentIndex != 1) {
      setState(() {
        _currentIndex = 1; // Switch to Map tab
      });
    }
  }

  List<Widget> _getScreens(bool isStaff) {
    return [
      const StudentDirectoryScreen(),
      const StudentMapScreen(),
      if (isStaff) const TrackingDashboardScreen(),
      const StudentProfileScreen(),
    ];
  }

  List<NavigationDestination> _getDestinations(bool isStaff) {
    return [
      const NavigationDestination(
        icon: Icon(Icons.people_outline),
        selectedIcon: Icon(Icons.people),
        label: 'Directory',
      ),
      const NavigationDestination(
        icon: Icon(Icons.map_outlined),
        selectedIcon: Icon(Icons.map),
        label: 'Map',
      ),
      if (isStaff)
        const NavigationDestination(
          icon: Icon(Icons.location_on_outlined),
          selectedIcon: Icon(Icons.location_on),
          label: 'Tracking',
        ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: 'Profile',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isStaff = authProvider.user?.isStaff ?? false;

    // If staff status just changed to true, ensure LocationProvider is initialized
    if (isStaff != _lastIsStaff) {
      _lastIsStaff = isStaff;
      if (isStaff && authProvider.user != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.read<LocationProvider>().initialize(
              authProvider.user!.id,
              campusId: authProvider.user!.campusId,
            );
          }
        });
      }
    }

    final screens = _getScreens(isStaff);
    if (_currentIndex >= screens.length) {
      _currentIndex = (screens.length - 1).clamp(0, screens.length - 1);
    }

    // Use responsive builder to adapt layout
    return ResponsiveBuilder(
      builder: (context, screenSize, deviceType) {
        // On desktop/tablet, use navigation rail/drawer
        if (deviceType != DeviceType.mobile) {
          return _buildAdaptiveLayout(context, deviceType, screens, isStaff);
        }

        // On mobile, use traditional bottom navigation
        return _buildMobileLayout(context, screens, isStaff);
      },
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    List<Widget> screens,
    bool isStaff,
  ) {
    final destinations = _getDestinations(isStaff);
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex.clamp(0, destinations.length - 1),
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          destinations: destinations,
        ),
      ),
    );
  }

  Widget _buildAdaptiveLayout(
    BuildContext context,
    DeviceType deviceType,
    List<Widget> screens,
    bool isStaff,
  ) {
    final destinations = [
      NavigationRailDestination(
        icon: const Icon(Icons.people_outline),
        selectedIcon: const Icon(Icons.people),
        label: const Text('Directory'),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.map_outlined),
        selectedIcon: const Icon(Icons.map),
        label: const Text('Map'),
      ),
      if (isStaff)
        NavigationRailDestination(
          icon: const Icon(Icons.location_on_outlined),
          selectedIcon: const Icon(Icons.location_on),
          label: const Text('Tracking'),
        ),
      NavigationRailDestination(
        icon: const Icon(Icons.person_outline),
        selectedIcon: const Icon(Icons.person),
        label: const Text('Profile'),
      ),
    ];

    return Scaffold(
      body: Row(
        children: [
          // Navigation rail for tablet, extended drawer for desktop
          if (deviceType == DeviceType.desktop)
            _buildNavigationDrawer(isStaff)
          else
            NavigationRail(
              selectedIndex: _currentIndex.clamp(0, destinations.length - 1),
              onDestinationSelected: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              labelType: NavigationRailLabelType.all,
              backgroundColor: AppColors.surface,
              destinations: destinations,
            ),

          const VerticalDivider(thickness: 1, width: 1),

          // Main content
          Expanded(
            child: IndexedStack(index: _currentIndex, children: screens),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationDrawer(bool isStaff) {
    final items = [
      (Icons.people_outline, Icons.people, 'Directory'),
      (Icons.map_outlined, Icons.map, 'Map'),
      if (isStaff) (Icons.location_on_outlined, Icons.location_on, 'Tracking'),
      (Icons.person_outline, Icons.person, 'Profile'),
    ];

    return SizedBox(
      width: 280,
      child: Drawer(
        elevation: 0,
        shape: const RoundedRectangleBorder(),
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(color: AppColors.primary),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.location_on,
                        color: AppColors.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'ISKSULARS TRACK',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Navigation items
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final (icon, selectedIcon, label) = items[index];
                  final isSelected = index == _currentIndex;

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: ListTile(
                      leading: Icon(
                        isSelected ? selectedIcon : icon,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      title: Text(
                        label,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                      selected: isSelected,
                      selectedTileColor: AppColors.primary.withValues(
                        alpha: 0.1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onTap: () {
                        setState(() {
                          _currentIndex = index;
                        });
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
