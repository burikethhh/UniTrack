import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/map_constants.dart';
import '../../core/utils/helpers.dart';
import '../../providers/providers.dart';
import '../../services/activity_log_service.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';
import '../../widgets/map/map_view_controls.dart';

/// Live map screen showing faculty locations with 3D / satellite / ground views
class StudentMapScreen extends StatefulWidget {
  final String? initialFacultyId;

  const StudentMapScreen({super.key, this.initialFacultyId});

  @override
  State<StudentMapScreen> createState() => _StudentMapScreenState();
}

class _StudentMapScreenState extends State<StudentMapScreen> {
  FacultyWithLocation? _selectedFaculty;
  LatLng? _userLocation;
  bool _use3DMap = false;
  MapViewMode _mapMode = MapViewMode.satellite;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String? _selectedCampusId;
  bool _showLegend = false;

  // 2D route state
  bool _showRoute = false;
  List<LatLng>? _routePoints;

  // Controllers for map interaction
  final GlobalKey<CampusMap3DState> _map3dKey = GlobalKey<CampusMap3DState>();
  final GlobalKey<CampusMapState> _map2dKey = GlobalKey<CampusMapState>();
  Timer? _locationRefreshTimer;
  StreamSubscription? _arrivalSub;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    ActivityLogService().logMapView();

    // Refresh student's own GPS every 30 seconds
    _locationRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _getCurrentLocation(),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final userCampusId =
          authProvider.user?.campusId ?? AppConstants.defaultCampusId;
      setState(() {
        _selectedCampusId = userCampusId;
      });

      // Listen for faculty arrivals and show toast
      _arrivalSub = context.read<FacultyProvider>().onFacultyArrived.listen((
        f,
      ) {
        if (!mounted) return;
        // Only notify if faculty belongs to selected campus (or all)
        if (_selectedCampusId != null && f.user.campusId != _selectedCampusId) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.person_pin_circle,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${f.user.fullName} just arrived on campus',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.accent,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () {
                setState(() => _selectedFaculty = f);
              },
            ),
          ),
        );
      });
    });

    if (widget.initialFacultyId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final provider = context.read<FacultyProvider>();
        final faculty = provider.getFacultyById(widget.initialFacultyId!);
        if (faculty != null) {
          setState(() => _selectedFaculty = faculty);
          provider.setFocusedFaculty(widget.initialFacultyId);
        }
      });
    }
  }

  @override
  void dispose() {
    _locationRefreshTimer?.cancel();
    _arrivalSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _animateToCampus(String campusId) {
    if (_use3DMap) {
      _map3dKey.currentState?.centerOnCampus(campusId: campusId);
    } else {
      _map2dKey.currentState?.animateToCampus(campusId);
    }
  }

  void _goToMyLocation() {
    _getCurrentLocation().then((_) {
      if (_userLocation != null && mounted) {
        if (_use3DMap) {
          _map3dKey.currentState?.centerOnUser();
        } else {
          _map2dKey.currentState?.flyTo(_userLocation!, 18.0);
        }
      }
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      final locationProvider = context.read<LocationProvider>();
      final position = await locationProvider.getCurrentPosition();
      if (position != null && mounted) {
        setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);
        });
      }
    } catch (e) {
      debugPrint('Error getting current location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentCampusId = _selectedCampusId ?? AppConstants.defaultCampusId;

    return Scaffold(
      appBar: AppBar(
        title: Text(_use3DMap ? _appBarTitle : 'Campus Map'),
        actions: [
          IconButton(
            icon: Icon(_use3DMap ? Icons.map_outlined : Icons.threed_rotation),
            onPressed: () => setState(() => _use3DMap = !_use3DMap),
            tooltip: _use3DMap ? 'Switch to 2D' : 'Switch to 3D',
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _goToMyLocation,
            tooltip: 'My Location',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<FacultyProvider>().refresh(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Map ──
          Consumer2<FacultyProvider, AuthProvider>(
            builder: (context, facultyProvider, authProvider, _) {
              final displayFaculty = facultyProvider.mapFaculty
                  .where((f) => f.isOnline)
                  .toList();

              // Refresh selected faculty reference from live data
              if (_selectedFaculty != null) {
                final liveMatch = displayFaculty
                    .where((f) => f.user.id == _selectedFaculty!.user.id)
                    .firstOrNull;
                if (liveMatch != null &&
                    !identical(liveMatch, _selectedFaculty)) {
                  // Schedule state update for next frame to keep build() pure
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() => _selectedFaculty = liveMatch);
                    }
                  });
                }
              }

              // Clear stale selection if faculty went offline
              if (_selectedFaculty != null &&
                  !displayFaculty.any(
                    (f) => f.user.id == _selectedFaculty!.user.id,
                  )) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    if (_use3DMap) _map3dKey.currentState?.clearRoute();
                    setState(() {
                      _selectedFaculty = null;
                      _showRoute = false;
                      _routePoints = null;
                    });
                  }
                });
              }

              if (_use3DMap) {
                // 3D MapLibre GL Map (native platforms only)
                return CampusMap3D(
                  key: _map3dKey,
                  faculty: displayFaculty,
                  userLocation: _userLocation != null
                      ? maplibre.LatLng(
                          _userLocation!.latitude,
                          _userLocation!.longitude,
                        )
                      : null,
                  selectedFaculty: _selectedFaculty,
                  onMarkerTap: (faculty) {
                    _map3dKey.currentState?.clearRoute();
                    setState(() => _selectedFaculty = faculty);
                  },
                  showCampusBoundary: true,
                  enable3DBuildings: true,
                  campusId: currentCampusId,
                  viewMode: _mapMode,
                );
              } else {
                // 2D Flutter Map — reliable on web (pure Dart, no JS interop)
                return CampusMap(
                  key: _map2dKey,
                  faculty: displayFaculty,
                  userLocation: _userLocation,
                  selectedLocation: _selectedFaculty?.location?.latLng,
                  selectedFaculty: _selectedFaculty,
                  onMarkerTap: (faculty) {
                    setState(() => _selectedFaculty = faculty);
                  },
                  showCampusBoundary: true,
                  campusId: currentCampusId,
                  showRoute: _showRoute,
                  routePoints: _routePoints,
                );
              }
            },
          ),

          // ── Top controls: search + campus selector ──
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Column(
              children: [
                // Row 1: Search bar + campus picker
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(23),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search leaders...',
                            hintStyle: TextStyle(
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.6,
                              ),
                              fontSize: 14,
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                            suffixIcon: _isSearching
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _isSearching = false);
                                      context
                                          .read<FacultyProvider>()
                                          .clearFocusedFaculty();
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 13,
                            ),
                          ),
                          style: const TextStyle(fontSize: 14),
                          onChanged: (value) {
                            setState(() => _isSearching = value.isNotEmpty);
                            context.read<FacultyProvider>().search(value);
                          },
                          onSubmitted: (value) {
                            if (value.isNotEmpty) {
                              final provider = context.read<FacultyProvider>();
                              if (provider.filteredFaculty.isNotEmpty) {
                                final first = provider.filteredFaculty.first;
                                provider.setFocusedFaculty(first.user.id);
                                setState(() => _selectedFaculty = first);
                              }
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildCampusPill(currentCampusId),
                  ],
                ),
                // Row 2: 3D view mode dropdown (only in 3D)
                if (_use3DMap)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        MapViewModeDropdown(
                          currentMode: _mapMode,
                          onModeChanged: (mode) =>
                              setState(() => _mapMode = mode),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // ── Campus legend (bottom left) ──
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            bottom: _selectedFaculty != null ? 180 : 16,
            left: 12,
            child: CampusLegend(
              expanded: _showLegend,
              selectedCampusId: currentCampusId,
              onToggle: () => setState(() => _showLegend = !_showLegend),
              onCampusSelected: (campusId) {
                setState(() {
                  _selectedCampusId = campusId;
                  _showLegend = false;
                });
                _animateToCampus(campusId);
              },
            ),
          ),

          // ── Selected faculty bottom sheet ──
          if (_selectedFaculty != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: FacultyMapBottomSheet(
                faculty: _selectedFaculty!,
                distanceText: _getDistanceText(_selectedFaculty!),
                walkingTimeText: _getWalkingTimeText(_selectedFaculty!),
                onNavigate: () => _openDirections(_selectedFaculty!),
                onPing: () => pingFaculty(
                  context: context,
                  facultyId: _selectedFaculty!.user.id,
                  facultyName: _selectedFaculty!.user.fullName,
                ),
                onClose: () {
                  _map3dKey.currentState?.clearRoute();
                  setState(() {
                    _selectedFaculty = null;
                    _showRoute = false;
                    _routePoints = null;
                  });
                },
              ),
            ),
        ],
      ),
      floatingActionButton: _selectedFaculty == null
          ? FloatingActionButton.extended(
              onPressed: _showFacultyListSheet,
              icon: const Icon(Icons.list),
              label: const Text('List View'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  String get _appBarTitle {
    switch (_mapMode) {
      case MapViewMode.satellite:
        return 'Satellite View';
      case MapViewMode.buildings3D:
        return '3D Campus Map';
      case MapViewMode.groundLevel:
        return 'Ground Level View';
    }
  }

  String? _getDistanceText(FacultyWithLocation faculty) {
    if (_userLocation == null || faculty.location == null) return null;

    final distance = const Distance().as(
      LengthUnit.Meter,
      _userLocation!,
      faculty.location!.latLng,
    );

    if (distance < 1000) {
      return '${distance.toInt()}m';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)}km';
    }
  }

  String? _getWalkingTimeText(FacultyWithLocation faculty) {
    if (_userLocation == null || faculty.location == null) return null;

    final distance = const Distance().as(
      LengthUnit.Meter,
      _userLocation!,
      faculty.location!.latLng,
    );

    // Average walking speed: 83.33 m/min
    final minutes = (distance / 83.33).ceil();

    if (minutes < 1) {
      return 'Less than 1 min';
    } else if (minutes == 1) {
      return '1 min';
    } else {
      return '$minutes mins';
    }
  }

  void _showFacultyListSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Consumer<FacultyProvider>(
                builder: (context, provider, _) {
                  final onlineFaculty = provider.allFaculty
                      .where((f) => f.isOnline)
                      .where(
                        (f) =>
                            _selectedCampusId == null ||
                            f.user.campusId == _selectedCampusId,
                      )
                      .toList();

                  return Column(
                    children: [
                      // Handle
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      // Header
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.people, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedCampusId != null
? 'Online · ${_campusShortName(_selectedCampusId!)} (${onlineFaculty.length})'
                                     : 'Online (${onlineFaculty.length})',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Divider(height: 1),

                      // List
                      Expanded(
                        child: onlineFaculty.isEmpty
                            ? const EmptyState(
                                icon: Icons.location_off,
                                title: 'No faculty online',
                                message:
                                    'Check back later for available faculty',
                              )
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: onlineFaculty.length,
                                itemBuilder: (context, index) {
                                  final faculty = onlineFaculty[index];
                                  return FacultyCard(
                                    faculty: faculty,
                                    showDistance: true,
                                    distanceText: _getDistanceText(faculty),
                                    onTap: () {
                                      Navigator.pop(context);
                                      setState(() {
                                        _selectedFaculty = faculty;
                                      });
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  // ─── Campus compact pill selector ───────────────────────────
  Widget _buildCampusPill(String currentCampusId) {
    final campusList = AppConstants.campusList;
    final selected = campusList.firstWhere(
      (c) => c['id'] == currentCampusId,
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
        final isSelected = campus['id'] == currentCampusId;
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
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(23),
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

  /// Show walking direction line on the in-app map to this faculty
  void _openDirections(FacultyWithLocation faculty) async {
    if (faculty.location == null) return;

    // Focus the map on this faculty
    context.read<FacultyProvider>().setFocusedFaculty(faculty.user.id);

    if (_use3DMap) {
      final destLatLng = maplibre.LatLng(
        faculty.location!.latitude,
        faculty.location!.longitude,
      );

      if (_userLocation != null) {
        // Draw a direction line from user → faculty on the map
        final fromLatLng = maplibre.LatLng(
          _userLocation!.latitude,
          _userLocation!.longitude,
        );
        await _map3dKey.currentState?.showRoute(fromLatLng, destLatLng);
      } else {
        // No user location — just center on the faculty
        _map3dKey.currentState?.centerOnFaculty(faculty);
      }
    } else {
      // 2D route polyline from user → faculty
      if (_userLocation != null) {
        setState(() {
          _showRoute = true;
          _routePoints = [_userLocation!, faculty.location!.latLng];
        });
        // Fit camera to show both points
        _map2dKey.currentState?.fitRoute();
      } else {
        // No user location — just fly to faculty
        _map2dKey.currentState?.flyTo(faculty.location!.latLng, 18.0);
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.near_me, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _userLocation != null
                    ? 'Showing directions to ${faculty.user.firstName}'
                    : 'Showing ${faculty.user.firstName}\'s location',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _campusShortName(String campusId) {
    final campus = AppConstants.campusList.firstWhere(
      (c) => c['id'] == campusId,
      orElse: () => {'shortName': campusId},
    );
    return campus['shortName'] ?? campusId;
  }
}
