import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import 'faculty_detail_screen.dart';
import 'student_map_screen.dart';

/// Directory screen for browsing faculty
class StudentDirectoryScreen extends StatefulWidget {
  const StudentDirectoryScreen({super.key});
  
  @override
  State<StudentDirectoryScreen> createState() => _StudentDirectoryScreenState();
}

class _StudentDirectoryScreenState extends State<StudentDirectoryScreen> {
  final _searchController = TextEditingController();
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  /// Send a "looking for you" ping to a faculty member
  Future<void> _pingFaculty(BuildContext context, String facultyId, String facultyName) async {
    final authProvider = context.read<AuthProvider>();
    final notificationProvider = context.read<NotificationProvider>();
    
    final currentUser = authProvider.user;
    if (currentUser == null) return;
    
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.notifications_active, color: AppColors.info),
            ),
            const SizedBox(width: 12),
            const Text('Notify Teacher'),
          ],
        ),
        content: Text(
          'Send a notification to $facultyName that you\'re looking for them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.send, size: 18),
            label: const Text('Send'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.info,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
    
    if (confirmed != true || !context.mounted) return;
    
    try {
      final success = await notificationProvider.pingStaff(
        student: currentUser,
        staffId: facultyId,
        staffName: facultyName,
      );
      
      if (!success && context.mounted) {
        // Show error if there was one (like spam prevention)
        if (notificationProvider.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(notificationProvider.error!)),
                ],
              ),
              backgroundColor: AppColors.warning,
              behavior: SnackBarBehavior.floating,
            ),
          );
          notificationProvider.clearError();
          return;
        }
      }
      
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Notification sent to $facultyName'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(e.toString())),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Faculty Directory'),
        actions: [
          Consumer<FacultyProvider>(
            builder: (context, provider, _) {
              return IconButton(
                icon: Icon(
                  provider.showOnlineOnly
                      ? Icons.visibility
                      : Icons.visibility_off_outlined,
                ),
                tooltip: provider.showOnlineOnly 
                    ? 'Showing online only' 
                    : 'Show all',
                onPressed: provider.toggleOnlineOnly,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and filter section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search bar
                CustomTextField(
                  controller: _searchController,
                  hint: 'Search by name or department...',
                  prefixIcon: Icons.search,
                  onChanged: (value) {
                    context.read<FacultyProvider>().search(value);
                  },
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            context.read<FacultyProvider>().search('');
                          },
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                
                // Department filter chips
                Consumer<FacultyProvider>(
                  builder: (context, provider, _) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          FilterChip(
                            label: const Text('All'),
                            selected: provider.selectedDepartment == null,
                            onSelected: (_) {
                              provider.filterByDepartment(null);
                            },
                            selectedColor: AppColors.primary.withValues(alpha: 0.2),
                            checkmarkColor: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          ...provider.departments.map((dept) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(dept.shortName ?? dept.name),
                                selected: provider.selectedDepartment == dept.name,
                                onSelected: (_) {
                                  provider.filterByDepartment(
                                    provider.selectedDepartment == dept.name
                                        ? null
                                        : dept.name,
                                  );
                                },
                                selectedColor: AppColors.primary.withValues(alpha: 0.2),
                                checkmarkColor: AppColors.primary,
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          
          // Stats bar
          Consumer<FacultyProvider>(
            builder: (context, provider, _) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: AppColors.surfaceLight,
                child: Row(
                  children: [
                    Icon(
                      Icons.people,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${provider.filteredFaculty.length} faculty',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.statusAvailable,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${provider.onlineFaculty} online',
                      style: TextStyle(
                        color: AppColors.statusAvailable,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          
          // Faculty list
          Expanded(
            child: Consumer<FacultyProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
                
                if (provider.error != null) {
                  return ErrorState(
                    message: provider.error!,
                    onRetry: provider.refresh,
                  );
                }
                
                if (provider.filteredFaculty.isEmpty) {
                  return EmptyState(
                    icon: Icons.search_off,
                    title: 'No faculty found',
                    message: provider.searchQuery.isNotEmpty
                        ? 'Try a different search term'
                        : 'No faculty members available',
                    action: provider.searchQuery.isNotEmpty ||
                            provider.selectedDepartment != null ||
                            provider.showOnlineOnly
                        ? TextButton(
                            onPressed: provider.clearFilters,
                            child: const Text('Clear Filters'),
                          )
                        : null,
                  );
                }
                
                return RefreshIndicator(
                  onRefresh: provider.refresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: provider.filteredFaculty.length,
                    itemBuilder: (context, index) {
                      final faculty = provider.filteredFaculty[index];
                      return FacultyCard(
                        faculty: faculty,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FacultyDetailScreen(
                                facultyId: faculty.user.id,
                              ),
                            ),
                          );
                        },
                        onNavigate: faculty.isOnline
                            ? () {
                                // Navigate to in-app map with faculty location
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => StudentMapScreen(
                                      initialFacultyId: faculty.user.id,
                                    ),
                                  ),
                                );
                              }
                            : null,
                        onPing: faculty.isOnline
                            ? () => _pingFaculty(context, faculty.user.id, faculty.user.fullName)
                            : null,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
