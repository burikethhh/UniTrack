import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/helpers.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import 'faculty_detail_screen.dart';
import 'student_map_screen.dart';
import '../staff/notifications_screen.dart';
import '../../services/activity_log_service.dart';

/// Directory screen for browsing faculty
class StudentDirectoryScreen extends StatefulWidget {
  const StudentDirectoryScreen({super.key});

  @override
  State<StudentDirectoryScreen> createState() => _StudentDirectoryScreenState();
}

class _StudentDirectoryScreenState extends State<StudentDirectoryScreen> {
  final _searchController = TextEditingController();
  Timer? _searchLogDebounce;

  @override
  void dispose() {
    _searchController.dispose();
    _searchLogDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Faculty Directory'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(24),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Locate faculty and leaders on campus',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
        ),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, provider, _) {
              return IconButton(
                icon: Badge(
                  isLabelVisible: provider.unreadCount > 0,
                  label: provider.unreadCount > 99
                      ? const Text('99+')
                      : Text('${provider.unreadCount}'),
                  child: const Icon(Icons.notifications_outlined),
                ),
                tooltip: 'Notifications',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  );
                },
              );
            },
          ),
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Modern search bar
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.5),
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      context.read<FacultyProvider>().search(value);
                      setState(() {});
                      // Debounced search logging
                      _searchLogDebounce?.cancel();
                      if (value.length >= 3) {
                        _searchLogDebounce = Timer(
                          const Duration(seconds: 2),
                          () => ActivityLogService().logSearch(value),
                        );
                      }
                    },
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Search leaders...',
                      hintStyle: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.7),
                        fontWeight: FontWeight.normal,
                      ),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 16, right: 12),
                        child: Icon(
                          Icons.search,
                          color: AppColors.textSecondary,
                          size: 22,
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 0),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: IconButton(
                                icon: Icon(
                                  Icons.close,
                                  color: AppColors.textSecondary,
                                  size: 20,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  context.read<FacultyProvider>().search('');
                                  setState(() {});
                                },
                              ),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 0,
                        vertical: 14,
                      ),
                    ),
                  ),
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
                            selectedColor: AppColors.primary.withValues(
                              alpha: 0.2,
                            ),
                            checkmarkColor: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          ...provider.departments.map((dept) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(dept.shortName ?? dept.name),
                                selected:
                                    provider.selectedDepartment == dept.name,
                                onSelected: (_) {
                                  provider.filterByDepartment(
                                    provider.selectedDepartment == dept.name
                                        ? null
                                        : dept.name,
                                  );
                                },
                                selectedColor: AppColors.primary.withValues(
                                  alpha: 0.2,
                                ),
                                checkmarkColor: AppColors.primary,
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),

                // Availability status filter chips
                Consumer<FacultyProvider>(
                  builder: (context, provider, _) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildAvailabilityChip(
                            context,
                            label: 'All Status',
                            icon: Icons.people,
                            color: AppColors.textSecondary,
                            isSelected:
                                provider.selectedAvailabilityStatus == null &&
                                !provider.showOnlineOnly,
                            count: provider.totalFaculty,
                            onSelected: () {
                              provider.filterByAvailabilityStatus(null);
                              // Turn off online-only when selecting "All"
                              if (provider.showOnlineOnly) {
                                provider.toggleOnlineOnly();
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          _buildAvailabilityChip(
                            context,
                            label: 'Available',
                            icon: AvailabilityStatus.available.icon,
                            color: AvailabilityStatus.available.color,
                            isSelected:
                                provider.selectedAvailabilityStatus ==
                                AvailabilityStatus.available,
                            count: provider.countByStatus(
                              AvailabilityStatus.available,
                            ),
                            onSelected: () =>
                                provider.filterByAvailabilityStatus(
                                  provider.selectedAvailabilityStatus ==
                                          AvailabilityStatus.available
                                      ? null
                                      : AvailabilityStatus.available,
                                ),
                          ),
                          const SizedBox(width: 8),
                          _buildAvailabilityChip(
                            context,
                            label: 'Busy',
                            icon: AvailabilityStatus.busy.icon,
                            color: AvailabilityStatus.busy.color,
                            isSelected:
                                provider.selectedAvailabilityStatus ==
                                AvailabilityStatus.busy,
                            count: provider.countByStatus(
                              AvailabilityStatus.busy,
                            ),
                            onSelected: () =>
                                provider.filterByAvailabilityStatus(
                                  provider.selectedAvailabilityStatus ==
                                          AvailabilityStatus.busy
                                      ? null
                                      : AvailabilityStatus.busy,
                                ),
                          ),
                          const SizedBox(width: 8),
                          _buildAvailabilityChip(
                            context,
                            label: 'Teaching',
                            icon: AvailabilityStatus.teaching.icon,
                            color: AvailabilityStatus.teaching.color,
                            isSelected:
                                provider.selectedAvailabilityStatus ==
                                AvailabilityStatus.teaching,
                            count: provider.countByStatus(
                              AvailabilityStatus.teaching,
                            ),
                            onSelected: () =>
                                provider.filterByAvailabilityStatus(
                                  provider.selectedAvailabilityStatus ==
                                          AvailabilityStatus.teaching
                                      ? null
                                      : AvailabilityStatus.teaching,
                                ),
                          ),
                          const SizedBox(width: 8),
                          _buildAvailabilityChip(
                            context,
                            label: 'In Meeting',
                            icon: AvailabilityStatus.inMeeting.icon,
                            color: AvailabilityStatus.inMeeting.color,
                            isSelected:
                                provider.selectedAvailabilityStatus ==
                                AvailabilityStatus.inMeeting,
                            count: provider.countByStatus(
                              AvailabilityStatus.inMeeting,
                            ),
                            onSelected: () =>
                                provider.filterByAvailabilityStatus(
                                  provider.selectedAvailabilityStatus ==
                                          AvailabilityStatus.inMeeting
                                      ? null
                                      : AvailabilityStatus.inMeeting,
                                ),
                          ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
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
                  return const FacultyListSkeleton();
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
                    action:
                        provider.searchQuery.isNotEmpty ||
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
                  child: ResponsiveBuilder(
                    builder: (context, screenSize, deviceType) {
                      // Use grid on tablet/desktop
                      if (deviceType != DeviceType.mobile) {
                        return _buildFacultyGrid(context, provider);
                      }
                      // Use list on mobile
                      return _buildFacultyList(context, provider);
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

  /// Build faculty list for mobile
  Widget _buildFacultyList(BuildContext context, FacultyProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: provider.filteredFaculty.length,
      itemBuilder: (context, index) {
        return _buildFacultyItem(context, provider.filteredFaculty[index]);
      },
    );
  }

  /// Build faculty grid for tablet/desktop
  Widget _buildFacultyGrid(BuildContext context, FacultyProvider provider) {
    final columns = context.isDesktop ? 3 : 2;

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        childAspectRatio: 2.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: provider.filteredFaculty.length,
      itemBuilder: (context, index) {
        return _buildFacultyItem(context, provider.filteredFaculty[index]);
      },
    );
  }

  /// Build single faculty item
  Widget _buildFacultyItem(BuildContext context, FacultyWithLocation faculty) {
    return FacultyCard(
      faculty: faculty,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FacultyDetailScreen(facultyId: faculty.user.id),
          ),
        );
      },
      onNavigate: faculty.isOnline
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      StudentMapScreen(initialFacultyId: faculty.user.id),
                ),
              );
            }
          : null,
      onPing: faculty.isOnline
          ? () => pingFaculty(
              context: context,
              facultyId: faculty.user.id,
              facultyName: faculty.user.fullName,
            )
          : null,
    );
  }

  /// Build availability filter chip with icon and count
  Widget _buildAvailabilityChip(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required int count,
    required VoidCallback onSelected,
  }) {
    return FilterChip(
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : color),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.3)
                  : color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : color,
              ),
            ),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: color,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}
