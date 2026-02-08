import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';

/// Filter options for the Live Monitor
enum MonitorFilter { all, students, staff, onlineOnly }

/// Admin-only Live Monitor screen
/// Shows all users who have location sharing enabled on a real-time map
class LiveMonitorScreen extends StatefulWidget {
  const LiveMonitorScreen({super.key});

  @override
  State<LiveMonitorScreen> createState() => _LiveMonitorScreenState();
}

class _LiveMonitorScreenState extends State<LiveMonitorScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final MapController _mapController = MapController();
  MonitorFilter _filter = MonitorFilter.all;
  FacultyWithLocation? _selectedUser;
  bool _showPanel = false;
  double _currentZoom = 16.0;

  LatLng get _campusCenter {
    final center = AppConstants.getCampusCenter(AppConstants.defaultCampusId);
    if (center != null) {
      return LatLng(center[0], center[1]);
    }
    return LatLng(AppConstants.campusCenterLat, AppConstants.campusCenterLng);
  }

  /// Check if a user is "visible" for the monitor
  /// Unlike normal isOnline, this doesn't require isWithinCampus
  bool _isVisible(FacultyWithLocation f) {
    if (f.user.isTrackingEnabled != true) return false;
    if (f.location == null) return false;
    if (f.isLocationStale) return false;
    return true;
  }

  List<FacultyWithLocation> _applyFilter(List<FacultyWithLocation> users) {
    // First, only show users who are actively sharing location
    var visible = users.where(_isVisible).toList();

    switch (_filter) {
      case MonitorFilter.students:
        visible = visible.where((f) => f.user.role == UserRole.student).toList();
        break;
      case MonitorFilter.staff:
        visible = visible.where((f) => f.user.role == UserRole.staff || f.user.role == UserRole.admin).toList();
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
      case UserRole.staff:
        return AppColors.primary;
      case UserRole.admin:
        return Colors.orange;
    }
  }

  IconData _roleIcon(UserRole role) {
    switch (role) {
      case UserRole.student:
        return Icons.school;
      case UserRole.staff:
        return Icons.person;
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
            icon: const Icon(Icons.center_focus_strong),
            tooltip: 'Center on campus',
            onPressed: () {
              _mapController.move(_campusCenter, 17.0);
            },
          ),
        ],
      ),
      body: StreamBuilder<List<FacultyWithLocation>>(
        stream: _databaseService.getAllUsersWithLocationsStream(),
        builder: (context, snapshot) {
          final allUsers = snapshot.data ?? [];
          final filtered = _applyFilter(allUsers);
          final totalVisible = allUsers.where(_isVisible).length;
          final studentCount = allUsers.where((f) => _isVisible(f) && f.user.role == UserRole.student).length;
          final staffCount = allUsers.where((f) => _isVisible(f) && (f.user.role == UserRole.staff || f.user.role == UserRole.admin)).length;

          return Stack(
            children: [
              // Map
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _campusCenter,
                  initialZoom: 17.0,
                  minZoom: 14.0,
                  maxZoom: 19.0,
                  onMapEvent: _onMapEvent,
                  onTap: (_, _) {
                    setState(() {
                      _selectedUser = null;
                      _showPanel = false;
                    });
                  },
                ),
                children: [
                  // Satellite tiles
                  TileLayer(
                    urlTemplate: 'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}',
                    userAgentPackageName: 'com.sksu.unitrack',
                    maxZoom: 20,
                  ),
                  // Road label overlay
                  TileLayer(
                    urlTemplate: 'https://mt1.google.com/vt/lyrs=h&x={x}&y={y}&z={z}',
                    userAgentPackageName: 'com.sksu.unitrack',
                    maxZoom: 20,
                  ),
                  // Campus boundaries
                  PolygonLayer(polygons: _buildCampusBoundaries()),
                  // User markers
                  MarkerLayer(markers: _buildMarkers(filtered)),
                ],
              ),

              // Filter chips at top
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All ($totalVisible)', MonitorFilter.all),
                      const SizedBox(width: 8),
                      _buildFilterChip('Students ($studentCount)', MonitorFilter.students),
                      const SizedBox(width: 8),
                      _buildFilterChip('Staff ($staffCount)', MonitorFilter.staff),
                      const SizedBox(width: 8),
                      _buildFilterChip('On Campus', MonitorFilter.onlineOnly),
                    ],
                  ),
                ),
              ),

              // Connection indicator
              if (snapshot.connectionState == ConnectionState.waiting)
                Positioned(
                  top: 60,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  top: 60,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
            ],
          );
        },
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
        side: BorderSide(
          color: isActive ? AppColors.primary : Colors.white30,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  List<Marker> _buildMarkers(List<FacultyWithLocation> users) {
    // Cluster markers when there are many in close proximity
    final zoom = _currentZoom;
    if (zoom < 15 && users.length > 10) {
      return _buildClusteredMarkers(users);
    }
    
    return users.where((f) => f.location != null).map((f) {
      final color = _markerColor(f.user.role);
      final isSelected = _selectedUser?.user.id == f.user.id;
      final markerSize = isSelected ? 56.0 : 46.0;

      return Marker(
        point: f.location!.latLng,
        width: markerSize,
        height: markerSize,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _selectedUser = f;
              _showPanel = true;
            });
            _mapController.move(f.location!.latLng, 18.5);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            width: markerSize,
            height: markerSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.amber : color,
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
              child: _buildMarkerContent(f, color, isSelected),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildMarkerContent(FacultyWithLocation f, Color color, bool isSelected) {
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

  Widget _buildInitialsAvatar(FacultyWithLocation f, Color color, bool isSelected) {
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

  List<Marker> _buildClusteredMarkers(List<FacultyWithLocation> users) {
    final validUsers = users.where((f) => f.location != null).toList();
    final clusters = <_MarkerCluster>[];
    final used = <int>{};
    final clusterRadius = 0.002 * (18 - _currentZoom).clamp(1, 10); 

    for (int i = 0; i < validUsers.length; i++) {
      if (used.contains(i)) continue;
      final cluster = [validUsers[i]];
      used.add(i);

      for (int j = i + 1; j < validUsers.length; j++) {
        if (used.contains(j)) continue;
        final dist = _distance(
          validUsers[i].location!.latLng,
          validUsers[j].location!.latLng,
        );
        if (dist < clusterRadius) {
          cluster.add(validUsers[j]);
          used.add(j);
        }
      }
      clusters.add(_MarkerCluster(cluster));
    }

    return clusters.map((cluster) {
      if (cluster.users.length == 1) {
        // Single user — render normal marker
        final f = cluster.users.first;
        final color = _markerColor(f.user.role);
        final isSelected = _selectedUser?.user.id == f.user.id;
        final markerSize = isSelected ? 56.0 : 46.0;
        return Marker(
          point: f.location!.latLng,
          width: markerSize,
          height: markerSize,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedUser = f;
                _showPanel = true;
              });
              _mapController.move(f.location!.latLng, 18.5);
            },
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.amber : color,
                  width: isSelected ? 4 : 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipOval(
                child: _buildMarkerContent(f, color, isSelected),
              ),
            ),
          ),
        );
      }

      // Cluster marker
      return Marker(
        point: cluster.center,
        width: 52,
        height: 52,
        child: GestureDetector(
          onTap: () {
            // Zoom in to break cluster
            _mapController.move(cluster.center, _currentZoom + 2);
          },
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Text(
                '${cluster.users.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  double _distance(LatLng a, LatLng b) {
    final dx = a.latitude - b.latitude;
    final dy = a.longitude - b.longitude;
    return (dx * dx + dy * dy);
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
          Row(
            children: [
              _infoChip(
                icon: f.isWithinCampus ? Icons.check_circle : Icons.public,
                label: f.isWithinCampus ? 'On Campus' : 'Off Campus',
                color: f.isWithinCampus ? AppColors.accent : AppColors.info,
              ),
              const SizedBox(width: 8),
              _infoChip(
                icon: f.isMoving ? Icons.directions_walk : Icons.place,
                label: f.isMoving ? 'Moving' : 'Stationary',
                color: f.isMoving ? Colors.blue : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              _infoChip(
                icon: Icons.access_time,
                label: f.lastSeenText,
                color: f.isFreshLocation ? AppColors.accent : AppColors.textSecondary,
              ),
            ],
          ),

          if (f.location?.quickMessage != null && f.location!.quickMessage!.isNotEmpty) ...[
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

  void _onMapEvent(MapEvent event) {
    if (event is MapEventMove || event is MapEventMoveEnd) {
      final newZoom = _mapController.camera.zoom;
      if ((newZoom - _currentZoom).abs() > 0.3) {
        setState(() => _currentZoom = newZoom);
      }
    }
  }

  List<Polygon> _buildCampusBoundaries() {
    final List<Polygon> polygons = [];
    final campusColors = {
      'isulan': AppColors.primary,
      'tacurong': Colors.orange,
      'access': Colors.purple,
    };

    for (final campus in AppConstants.campusesData) {
      final campusId = campus['id'] as String;
      final boundary = campus['boundaryPoints'] as List;
      final color = campusColors[campusId] ?? AppColors.primary;

      final points = boundary
          .map<LatLng>((point) => LatLng(
                (point as List)[0] as double,
                point[1] as double,
              ))
          .toList();

      polygons.add(Polygon(
        points: points,
        color: color.withValues(alpha: 0.12),
        borderColor: color,
        borderStrokeWidth: 2.0,
      ));
    }

    return polygons;
  }
}

/// Helper class for marker clustering
class _MarkerCluster {
  final List<FacultyWithLocation> users;

  _MarkerCluster(this.users);

  LatLng get center {
    double lat = 0, lng = 0;
    for (final u in users) {
      lat += u.location!.latLng.latitude;
      lng += u.location!.latLng.longitude;
    }
    return LatLng(lat / users.length, lng / users.length);
  }
}
