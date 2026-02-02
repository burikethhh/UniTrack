import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;
import '../../core/theme/app_colors.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

/// Helper function to get initials from a full name (top-level for reuse)
String _getInitialsStatic(String fullName) {
  final parts = fullName.trim().split(' ');
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
  return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
}

/// Screen for staff to find and locate other staff members
class StaffDirectoryScreen extends StatefulWidget {
  const StaffDirectoryScreen({super.key});
  
  @override
  State<StaffDirectoryScreen> createState() => _StaffDirectoryScreenState();
}

class _StaffDirectoryScreenState extends State<StaffDirectoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedDepartment;
  bool _showOnlineOnly = false;
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Colleagues'),
        actions: [
          // Filter button
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter',
            onSelected: (value) {
              if (value == 'online') {
                setState(() {
                  _showOnlineOnly = !_showOnlineOnly;
                });
              } else if (value == 'clear') {
                setState(() {
                  _selectedDepartment = null;
                  _showOnlineOnly = false;
                });
              }
            },
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                value: 'online',
                checked: _showOnlineOnly,
                child: const Text('Online Only'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'clear',
                child: Text('Clear Filters'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search colleagues by name or department...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: AppColors.surface,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          
          // Department filter chips
          Consumer<FacultyProvider>(
            builder: (context, provider, _) {
              final departments = provider.departments;
              if (departments.isEmpty) return const SizedBox.shrink();
              
              return SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: departments.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FilterChip(
                          label: const Text('All'),
                          selected: _selectedDepartment == null,
                          onSelected: (_) {
                            setState(() {
                              _selectedDepartment = null;
                            });
                          },
                          selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      );
                    }
                    
                    final dept = departments[index - 1];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilterChip(
                        label: Text(dept.shortName ?? dept.name),
                        selected: _selectedDepartment == dept.name,
                        onSelected: (_) {
                          setState(() {
                            _selectedDepartment = _selectedDepartment == dept.name ? null : dept.name;
                          });
                        },
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          
          const SizedBox(height: 8),
          
          // Staff list
          Expanded(
            child: Consumer2<FacultyProvider, AuthProvider>(
              builder: (context, facultyProvider, authProvider, _) {
                final currentUserId = authProvider.user?.id;
                
                // Filter faculty (excluding current user)
                var staffList = facultyProvider.allFaculty
                    .where((f) => f.user.id != currentUserId) // Exclude self
                    .toList();
                
                // Apply search filter
                if (_searchQuery.isNotEmpty) {
                  final query = _searchQuery.toLowerCase();
                  staffList = staffList.where((f) {
                    return f.user.fullName.toLowerCase().contains(query) ||
                        (f.user.department?.toLowerCase().contains(query) ?? false) ||
                        (f.user.position?.toLowerCase().contains(query) ?? false);
                  }).toList();
                }
                
                // Apply department filter
                if (_selectedDepartment != null) {
                  staffList = staffList.where((f) => f.user.department == _selectedDepartment).toList();
                }
                
                // Apply online filter
                if (_showOnlineOnly) {
                  staffList = staffList.where((f) => f.isOnline).toList();
                }
                
                // Sort: online first, then by name
                staffList.sort((a, b) {
                  if (a.isOnline && !b.isOnline) return -1;
                  if (!a.isOnline && b.isOnline) return 1;
                  return a.user.fullName.compareTo(b.user.fullName);
                });
                
                if (staffList.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 80,
                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty || _selectedDepartment != null || _showOnlineOnly
                              ? 'No colleagues found'
                              : 'No colleagues available',
                          style: TextStyle(
                            fontSize: 18,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_searchQuery.isNotEmpty || _selectedDepartment != null || _showOnlineOnly) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _selectedDepartment = null;
                                _showOnlineOnly = false;
                              });
                            },
                            child: const Text('Clear filters'),
                          ),
                        ],
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: staffList.length,
                  itemBuilder: (context, index) {
                    final staff = staffList[index];
                    return _StaffCard(
                      staff: staff,
                      onTap: () => _showStaffDetails(context, staff),
                      onLocate: staff.isOnline ? () => _locateStaff(context, staff) : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  void _showStaffDetails(BuildContext context, FacultyWithLocation staff) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Avatar and name
              Row(
                children: [
                  FacultyAvatar(
                    imageUrl: staff.user.photoUrl,
                    initials: _getInitials(staff.user.fullName),
                    size: 70,
                    isOnline: staff.isOnline,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          staff.user.fullName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (staff.user.position != null)
                          Text(
                            staff.user.position!,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: staff.isOnline
                                ? AppColors.success.withValues(alpha: 0.1)
                                : AppColors.textSecondary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            staff.isOnline ? 'In Campus' : 'Offline',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: staff.isOnline ? AppColors.success : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Info cards
              _buildInfoRow(Icons.business, 'Department', staff.user.department ?? 'Not specified'),
              _buildInfoRow(Icons.location_city, 'Campus', staff.user.campusId),
              _buildInfoRow(Icons.email, 'Email', staff.user.email),
              if (staff.isOnline && staff.location != null)
                _buildInfoRow(Icons.access_time, 'Last seen', staff.lastSeenText),
              if (staff.isOnline && staff.displayStatus != 'Offline')
                _buildInfoRow(Icons.info_outline, 'Status', staff.displayStatus),
              
              const SizedBox(height: 24),
              
              // Action buttons
              if (staff.isOnline)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _locateStaff(context, staff);
                    },
                    icon: const Icon(Icons.location_on),
                    label: const Text('View on Map'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  void _locateStaff(BuildContext context, FacultyWithLocation staff) {
    // Navigate to map screen with staff selected
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _StaffLocatorMapScreen(targetStaff: staff),
      ),
    );
  }
  
  /// Get initials from a full name
  String _getInitials(String fullName) => _getInitialsStatic(fullName);
}

/// Card widget for displaying staff member
class _StaffCard extends StatelessWidget {
  final FacultyWithLocation staff;
  final VoidCallback onTap;
  final VoidCallback? onLocate;
  
  const _StaffCard({
    required this.staff,
    required this.onTap,
    this.onLocate,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar with online indicator
              FacultyAvatar(
                imageUrl: staff.user.photoUrl,
                initials: _getInitials(staff.user.fullName),
                size: 56,
                isOnline: staff.isOnline,
              ),
              const SizedBox(width: 16),
              
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      staff.user.fullName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (staff.user.position != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        staff.user.position!,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.business,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            staff.user.department ?? 'No department',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: staff.isOnline
                            ? AppColors.success.withValues(alpha: 0.1)
                            : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        staff.isOnline ? 'In Campus' : 'Offline',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: staff.isOnline ? AppColors.success : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Locate button
              if (onLocate != null)
                Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onLocate,
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(
                          Icons.location_on,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Get initials from a full name  
  String _getInitials(String fullName) => _getInitialsStatic(fullName);
}

/// Map screen for locating a specific staff member
class _StaffLocatorMapScreen extends StatelessWidget {
  final FacultyWithLocation targetStaff;
  
  const _StaffLocatorMapScreen({required this.targetStaff});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Locating ${targetStaff.user.firstName}'),
      ),
      body: Consumer<LocationProvider>(
        builder: (context, locationProvider, _) {
          final userLocation = locationProvider.currentLocation;
          
          return Stack(
            children: [
              // 3D Map
              CampusMap3D(
                faculty: [targetStaff],
                userLocation: userLocation != null
                    ? LatLng(userLocation.latitude, userLocation.longitude)
                    : null,
                selectedFaculty: targetStaff,
                focusOnSelected: true,
                showCampusBoundary: true,
              ),
              
              // Info card at bottom
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        FacultyAvatar(
                          imageUrl: targetStaff.user.photoUrl,
                          initials: _getInitialsStatic(targetStaff.user.fullName),
                          size: 50,
                          isOnline: true,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                targetStaff.user.fullName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                targetStaff.displayStatus,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (targetStaff.location?.quickMessage != null)
                                Text(
                                  targetStaff.location!.quickMessage!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primary,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Distance indicator (if user location available)
                        if (userLocation != null && targetStaff.location != null)
                          _buildDistanceChip(context, userLocation, targetStaff.location!),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
  
  Widget _buildDistanceChip(BuildContext context, LocationModel userLoc, LocationModel staffLoc) {
    final distance = _calculateDistance(
      userLoc.latitude, userLoc.longitude,
      staffLoc.latitude, staffLoc.longitude,
    );
    
    final distanceText = distance < 1000
        ? '${distance.toStringAsFixed(0)}m'
        : '${(distance / 1000).toStringAsFixed(1)}km';
    
    final walkingMinutes = (distance / 83.33).ceil(); // 83.33 m/min walking speed
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.directions_walk, size: 20, color: AppColors.info),
          Text(
            distanceText,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.info,
            ),
          ),
          Text(
            '~$walkingMinutes min',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.info.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
  
  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371000; // meters
    final double dLat = _toRadians(lat2 - lat1);
    final double dLng = _toRadians(lng2 - lng1);
    
    final double a = _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(_toRadians(lat1)) * _cos(_toRadians(lat2)) *
        _sin(dLng / 2) * _sin(dLng / 2);
    final double c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  double _toRadians(double degrees) => degrees * 3.14159265359 / 180;
  double _sin(double x) => _sinTaylor(x);
  double _cos(double x) => _sinTaylor(x + 1.5707963268);
  double _sqrt(double x) => _sqrtNewton(x);
  double _atan2(double y, double x) => _atan2Impl(y, x);
  
  double _sinTaylor(double x) {
    x = x % (2 * 3.14159265359);
    double result = 0, term = x;
    for (int n = 1; n <= 10; n++) {
      result += term;
      term *= -x * x / ((2 * n) * (2 * n + 1));
    }
    return result;
  }
  
  double _sqrtNewton(double x) {
    if (x <= 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 10; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }
  
  double _atan2Impl(double y, double x) {
    if (x > 0) return _atan(y / x);
    if (x < 0 && y >= 0) return _atan(y / x) + 3.14159265359;
    if (x < 0 && y < 0) return _atan(y / x) - 3.14159265359;
    if (x == 0 && y > 0) return 1.5707963268;
    if (x == 0 && y < 0) return -1.5707963268;
    return 0;
  }
  
  double _atan(double x) {
    double result = 0, term = x;
    for (int n = 0; n < 20; n++) {
      result += term / (2 * n + 1) * (n % 2 == 0 ? 1 : -1);
      term *= x * x;
    }
    return result;
  }
}
