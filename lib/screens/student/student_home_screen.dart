import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/providers.dart';
import 'student_directory_screen.dart';
import 'student_map_screen.dart';
import 'student_profile_screen.dart';

/// Main screen for student module with bottom navigation
class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});
  
  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  int _currentIndex = 0;
  
  final List<Widget> _screens = [
    const StudentDirectoryScreen(),
    const StudentMapScreen(),
    const StudentProfileScreen(),
  ];
  
  @override
  void initState() {
    super.initState();
    // Initialize faculty provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FacultyProvider>().initialize();
      // Initialize location provider for student location sharing
      final authProvider = context.read<AuthProvider>();
      if (authProvider.user != null) {
        context.read<LocationProvider>().initialize(
          authProvider.user!.id,
          campusId: authProvider.user!.campusId,
        );
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
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
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: 'Directory',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined),
              activeIcon: Icon(Icons.map),
              label: 'Map',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
