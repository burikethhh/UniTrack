import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/map_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../widgets/map/campus_map.dart';
import '../../widgets/map/campus_map_3d.dart';
import '../../widgets/map/map_view_controls.dart';

/// Filter options for the Live Monitor
enum MonitorFilter { all, students, studentLeaders, orgOfficers, onlineOnly }

/// Admin-only Live Monitor screen
/// Shows all users who have location sharing enabled on a real-time map
class LiveMonitorScreen extends StatefulWidget {
  const LiveMonitorScreen({super.key});

  @override
  State<LiveMonitorScreen> createState() => _LiveMonitorScreenState();
}

class _LiveMonitorScreenState extends State<LiveMonitorScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final GlobalKey<CampusMapState> _map2dKey = GlobalKey<CampusMapState>();
  final GlobalKey<CampusMap3DState> _map3dKey = GlobalKey<CampusMap3DState>();
  MonitorFilter _filter = MonitorFilter.all;
  FacultyWithLocation? _selectedUser;
  bool _showPanel = false;
  bool _use3DMap = false;
  MapViewMode _mapMode = MapViewMode.satellite;
  String? _selectedCampusId;

  /// Cached stream — created once, reused across rebuilds so StreamBuilder
  /// doesn't re-subscribe on every setState.
  late Stream<List<FacultyWithLocation>> _usersStream = _databaseService
      .getAllUsersWithLocationsStream();

  @override
  void dispose() {
    super.dispose();
  }

  void _animateToCampus(String campusId) {
    if (_use3DMap) {
      _map3dKey.currentState?.centerOnCampus(campusId: campusId);
    } else {
      _map2dKey.currentState?.animateToCampus(campusId);
    }
  }

  /// Check if a user is "visible" for the monitor
  /// Unlike normal isOnline, this doesn't require isWithinCampus
  /// Note: isTrackingEnabled is bool? — treat null as enabled so
  /// users whose field hasn't been written yet are still visible.
  /// Only hide when explicitly set to false.
  bool _isVisible(FacultyWithLocation f) {
    if (f.user.isTrackingEnabled == false) return false;
    if (f.location == null) return false;
    if (f.isLocationStale) return false;
    return true;
  }

  List<FacultyWithLocation> _applyFilter(List<FacultyWithLocation> users) {
    // First, only show users who are actively sharing location
    var visible = users.where(_isVisible).toList();

    // Filter by selected campus if one is chosen
    if (_selectedCampusId != null) {
      visible = visible
          .where((f) => f.user.campusId == _selectedCampusId)
          .toList();
    }

    switch (_filter) {
      case MonitorFilter.students:
        visible = visible
            .where((f) => f.user.role == UserRole.student)
            .toList();
        break;
      case MonitorFilter.studentLeaders:
        visible = visible
            .where((f) => f.user.role == UserRole.studentLeader)
            .toList();
        break;
      case MonitorFilter.orgOfficers:
        visible = visible
            .where((f) => f.user.role == UserRole.organizationOfficer)
            .toList();
        break;
      case MonitorFilter.onlineOnly:
        visible = visible.where((f) => f.isOnline).toList();
        break;
      case MonitorFilter.all:
        break;
    }

    return visible;
  }

  Color _markerColor(UserRole role) {
    switch (role) {
      case UserRole.student:
        return Colors.blue;
      case UserRole.studentLeader:
        return Colors.orange;
      case UserRole.organizationOfficer:
        return Colors.teal;
      case UserRole.admin:
        return Colors.purple;
    }
  }

  IconData _roleIcon(UserRole role) {
    switch (role) {
      case UserRole.student:
        return Icons.school;
      case UserRole.studentLeader:
        return Icons.account_balance;
      case UserRole.organizationOfficer:
        return Icons.groups;
      case UserRole.admin:
        return Icons.admin_panel_settings;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Monitor'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(_use3DMap ? Icons.map_outlined : Icons.threed_rotation),
            tooltip: _use3DMap ? 'Switch to 2D' : 'Switch to 3D',
            onPressed: () => setState(() => _use3DMap = !_use3DMap),
          ),
          if (!_use3DMap)
            IconButton(
              icon: const Icon(Icons.my_location),
              tooltip: 'Center on campus',
              onPressed: () {
                _map2dKey.currentState?.animateToCampus(
                  _selectedCampusId ?? AppConstants.defaultCampusId,
                );
              },
            ),
        ],
      ),
      body: StreamBuilder<List<FacultyWithLocation>>(
        stream: _usersStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text('Error loading live data: ${snapshot.error}'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _usersStream = _databaseService
                            .getAllUsersWithLocationsStream();
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          final allUsers = snapshot.data ?? [];
          final filtered = _applyFilter(allUsers);
          final visibleUsers = allUsers.where(_isVisible).toList();
          final totalVisible = visibleUsers.length;
          final studentCount = visibleUsers
              .where((f) => f.user.role == UserRole.student)
              .length;
          final leaderCount = visibleUsers
              .where((f) => f.user.role == UserRole.studentLeader)
              .length;
          final officerCount = visibleUsers
              .where((f) => f.user.role == UserRole.organizationOfficer)
              .length;
          final onCampusCount = visibleUsers
              .where((f) => f.isWithinCampus)
              .length;
          final offCampusCount = totalVisible - onCampusCount;

          return Stack(
            children: [
              // Map — 2D or 3D
              if (_use3DMap)
                CampusMap3D(
                  key: _map3dKey,
                  faculty: filtered,
                  selectedFaculty: _selectedUser,
                  onMarkerTap: (faculty) {
                    setState(() {
                      _selectedUser = faculty;
                      _showPanel = true;
                    });
                  },
                  showCampusBoundary: true,
                  enable3DBuildings: true,
                  campusId: _selectedCampusId ?? AppConstants.defaultCampusId,
                  viewMode: _mapMode,
                )
              else
                CampusMap(
                  key: _map2dKey,
                  faculty: filtered,
                  selectedFaculty: _selectedUser,
                  onMarkerTap: (faculty) {
                    setState(() {
                      _selectedUser = faculty;
                      _showPanel = true;
                    });
                  },
                  showCampusBoundary: true,
                  campusId: _selectedCampusId ?? AppConstants.defaultCampusId,
                  onTap: (_, _) {
                    setState(() {
                      _selectedUser = null;
                      _showPanel = false;
                    });
                  },
                  customMarkerBuilder: (faculty, isSelected) {
                    final color = _markerColor(faculty.user.role);
                    final markerSize = isSelected ? 56.0 : 46.0;
                    // Green ring = on campus, orange ring = off campus
                    final campusRingColor = isSelected
                        ? Colors.amber
                        : faculty.isWithinCampus
                        ? Colors.greenAccent
                        : Colors.orangeAccent;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      width: markerSize,
                      height: markerSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: campusRingColor,
                          width: isSelected ? 4 : 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isSelected
                                ? Colors.amber.withValues(alpha: 0.6)
                                : color.withValues(alpha: 0.5),
                            blurRadius: isSelected ? 14 : 8,
                            spreadRadius: isSelected ? 3 : 1,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: _buildMarkerContent(faculty, color, isSelected),
                      ),
                    );
                  },
                ),

              // Top controls: view mode (3D) + campus selector + filter chips
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: View mode dropdown (3D) + campus selector
                    Row(
                      children: [
                        if (_use3DMap)
                          MapViewModeDropdown(
                            currentMode: _mapMode,
                            onModeChanged: (mode) =>
                                setState(() => _mapMode = mode),
                          ),
                        const Spacer(),
                        _buildCampusPill(),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Row 2: Campus status counts
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: Colors.greenAccent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'On Campus: $onCampusCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.location_off,
                            size: 14,
                            color: Colors.orangeAccent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Off Campus: $offCampusCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Row 3: Filter chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip(
                            'All ($totalVisible)',
                            MonitorFilter.all,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'Students ($studentCount)',
                            MonitorFilter.students,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'Leaders ($leaderCount)',
                            MonitorFilter.studentLeaders,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'Officers ($officerCount)',
                            MonitorFilter.orgOfficers,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'On Campus',
                            MonitorFilter.onlineOnly,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Connection indicator
              if (snapshot.connectionState == ConnectionState.waiting)
                Positioned(
                  top: 100,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Connecting...',
                            style: TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Live indicator
              if (snapshot.hasData)
                Positioned(
                  top: 100,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'LIVE · ${filtered.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // User info panel
              if (_showPanel && _selectedUser != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildUserPanel(_selectedUser!),
                ),

              // Center on campus FAB
              Positioned(
                bottom: _showPanel ? 260 : 24,
                right: 16,
                child: FloatingActionButton(
                  heroTag: 'centerCampus',
                  onPressed: () {
                    if (_use3DMap) {
                      _map3dKey.currentState?.centerOnCampus(
                        campusId: _selectedCampusId ?? AppConstants.defaultCampusId,
                      );
                    } else {
                      _map2dKey.currentState?.animateToCampus(
                        _selectedCampusId ?? AppConstants.defaultCampusId,
                      );
                    }
                  },
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  tooltip: 'Center on campus',
                  child: const Icon(Icons.my_location),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCampusPill() {
    final campusList = AppConstants.campusList;
    final currentId = _selectedCampusId ?? AppConstants.defaultCampusId;
    final selected = campusList.firstWhere(
      (c) => c['id'] == currentId,
      orElse: () => campusList.first,
    );

    return PopupMenuButton<String>(
      onSelected: (campusId) {
        setState(() => _selectedCampusId = campusId);
        _animateToCampus(campusId);
      },
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (context) => campusList.map((campus) {
        final isSelected = campus['id'] == currentId;
        return PopupMenuItem<String>(
          value: campus['id']!,
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppColors.primary : AppColors.border,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                campus['shortName'] ?? campus['name']!,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(21),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_city, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              selected['shortName'] ?? 'Campus',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, MonitorFilter filter) {
    final isActive = _filter == filter;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isActive ? Colors.white : Colors.white70,
          fontSize: 13,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isActive,
      onSelected: (_) {
        setState(() => _filter = filter);
      },
      backgroundColor: Colors.black54,
      selectedColor: AppColors.primary,
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isActive ? AppColors.primary : Colors.white30),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildMarkerContent(
    FacultyWithLocation f,
    Color color,
    bool isSelected,
  ) {
    if (f.user.photoUrl != null && f.user.photoUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: f.user.photoUrl!,
        fit: BoxFit.cover,
        placeholder: (_, _) => _buildInitialsAvatar(f, color, isSelected),
        errorWidget: (_, _, _) => _buildInitialsAvatar(f, color, isSelected),
      );
    }
    return _buildInitialsAvatar(f, color, isSelected);
  }

  Widget _buildInitialsAvatar(
    FacultyWithLocation f,
    Color color,
    bool isSelected,
  ) {
    return Container(
      color: color,
      child: Center(
        child: Text(
          f.user.initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: isSelected ? 15 : 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildUserPanel(FacultyWithLocation f) {
    final color = _markerColor(f.user.role);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 26,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Text(
                  f.user.initials,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.user.fullName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(_roleIcon(f.user.role), size: 14, color: color),
                        const SizedBox(width: 4),
                        Text(
                          f.user.roleString,
                          style: TextStyle(
                            color: color,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (f.user.department != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '· ${f.user.department}',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _showPanel = false;
                    _selectedUser = null;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Location details
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _infoChip(
                icon: f.isWithinCampus ? Icons.check_circle : Icons.public,
                label: f.isWithinCampus ? 'On Campus' : 'Off Campus',
                color: f.isWithinCampus ? AppColors.accent : AppColors.info,
              ),
              _infoChip(
                icon: f.isMoving ? Icons.directions_walk : Icons.place,
                label: f.isMoving ? 'Moving' : 'Stationary',
                color: f.isMoving ? Colors.blue : AppColors.textSecondary,
              ),
              _infoChip(
                icon: Icons.access_time,
                label: f.lastSeenText,
                color: f.isFreshLocation
                    ? AppColors.accent
                    : AppColors.textSecondary,
              ),
            ],
          ),

          if (f.location?.quickMessage != null &&
              f.location!.quickMessage!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.message, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      f.location!.quickMessage!,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
