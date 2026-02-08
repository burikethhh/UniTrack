import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../models/models.dart';

/// 3D Campus map widget using MapLibre GL
class CampusMap3D extends StatefulWidget {
  final List<FacultyWithLocation>? faculty;
  final LatLng? userLocation;
  final LatLng? selectedLocation;
  final FacultyWithLocation? selectedFaculty; // Faculty to focus on
  final Function(FacultyWithLocation)? onMarkerTap;
  final bool showCampusBoundary;
  final bool enable3DBuildings;
  final String? campusId; // Campus to display (defaults to Isulan)
  final bool focusOnSelected; // Whether to auto-center on selected faculty
  
  const CampusMap3D({
    super.key,
    this.faculty,
    this.userLocation,
    this.selectedLocation,
    this.selectedFaculty,
    this.onMarkerTap,
    this.showCampusBoundary = true,
    this.enable3DBuildings = true,
    this.campusId,
    this.focusOnSelected = false,
  });
  
  @override
  State<CampusMap3D> createState() => _CampusMap3DState();
}

class _CampusMap3DState extends State<CampusMap3D> with AutomaticKeepAliveClientMixin {
  MapLibreMapController? _mapController;
  final Map<String, Circle> _facultyCircles = {};
  Circle? _userLocationCircle;
  bool _mapReady = false;
  bool _isDisposed = false; // Track disposal state
  // ignore: prefer_final_fields
  Key _mapKey = UniqueKey(); // Unique key for map recreation
  
  @override
  bool get wantKeepAlive => true; // Keep map alive during navigation
  
  // Get campus center based on campusId
  LatLng get _campusCenter {
    final campusId = widget.campusId ?? AppConstants.defaultCampusId;
    final center = AppConstants.getCampusCenter(campusId);
    if (center != null) {
      return LatLng(center[0], center[1]);
    }
    // Fallback to Isulan campus
    return LatLng(AppConstants.campusCenterLat, AppConstants.campusCenterLng);
  }
  
  // Satellite map style using raster tiles
  // Custom style JSON for satellite view with hybrid labels
  // Build map style dynamically with campus boundaries baked in
  // This is more reliable on web than calling addSource/addLayer at runtime
  static String _buildMapStyle({bool includeBoundaries = true}) {
    final sources = <String, dynamic>{
      'satellite': {
        'type': 'raster',
        'tiles': ['https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'],
        'tileSize': 256,
        'maxzoom': 20,
      },
    };

    final layers = <Map<String, dynamic>>[
      {
        'id': 'satellite-layer',
        'type': 'raster',
        'source': 'satellite',
      },
    ];

    if (includeBoundaries) {
      const campusColors = {
        'isulan': '#E8A87C',
        'tacurong': '#FF9800',
        'access': '#9C27B0',
        'bagumbayan': '#009688',
        'palimbang': '#3F51B5',
        'kalamansig': '#E91E63',
        'lutayan': '#795548',
      };

      for (final campus in AppConstants.campusesData) {
        final campusId = campus['id'] as String;
        final boundary = campus['boundaryPoints'] as List;
        final color = campusColors[campusId] ?? '#E8A87C';

        final coordinates = boundary
            .map<List<double>>((point) => [
                  (point as List)[1] as double,
                  point[0] as double,
                ])
            .toList();

        if (coordinates.isNotEmpty) {
          coordinates.add(List<double>.from(coordinates.first));
        }

        final sourceId = 'campus-boundary-$campusId';
        sources[sourceId] = {
          'type': 'geojson',
          'data': {
            'type': 'Feature',
            'geometry': {
              'type': 'Polygon',
              'coordinates': [coordinates],
            },
          },
        };

        layers.add({
          'id': 'campus-fill-$campusId',
          'type': 'fill',
          'source': sourceId,
          'paint': {
            'fill-color': color,
            'fill-opacity': 0.15,
          },
        });

        layers.add({
          'id': 'campus-line-$campusId',
          'type': 'line',
          'source': sourceId,
          'paint': {
            'line-color': color,
            'line-width': 3.0,
            'line-opacity': 0.9,
          },
        });
      }
    }

    return jsonEncode({
      'version': 8,
      'name': 'SKSU Campus Satellite',
      'glyphs': 'https://demotiles.maplibre.org/font/{fontstack}/{range}.pbf',
      'sources': sources,
      'layers': layers,
    });
  }
  
  @override
  void dispose() {
    _isDisposed = true;
    _mapReady = false;
    // Don't call dispose on controller - MapLibre handles this internally
    _mapController = null;
    super.dispose();
  }
  
  @override
  void didUpdateWidget(CampusMap3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isDisposed || !mounted) return;
    if (_mapReady && widget.faculty != oldWidget.faculty) {
      _updateFacultyMarkers();
    }
    if (_mapReady && widget.userLocation != oldWidget.userLocation) {
      _updateUserLocationMarker();
    }
    // Focus on selected faculty when it changes
    if (_mapReady && widget.selectedFaculty != oldWidget.selectedFaculty && widget.selectedFaculty != null) {
      _centerOnFaculty(widget.selectedFaculty!);
    }
  }
  
  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
  }
  
  void _onStyleLoaded() {
    if (_isDisposed) return;
    
    setState(() {
      _mapReady = true;
    });
    
    // Note: 3D buildings are not supported with the satellite raster style
    // (no vector "building" source exists). Skipping _enable3DBuildings().
    
    // Campus boundaries are embedded in the style JSON — no runtime calls needed.
    
    // Add markers
    _updateFacultyMarkers();
    _updateUserLocationMarker();
    
    // Tilt camera for 3D effect - focus on selected faculty if available
    if (widget.selectedFaculty != null && widget.selectedFaculty!.location != null) {
      _centerOnFaculty(widget.selectedFaculty!);
    } else {
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _campusCenter,
            zoom: 17.0,
            tilt: 45.0, // 3D tilt
            bearing: 0.0,
          ),
        ),
      );
    }
  }
  
  /// Center the map on a specific faculty's location
  void _centerOnFaculty(FacultyWithLocation faculty) {
    if (faculty.location == null || _mapController == null || _isDisposed || !mounted) return;
    
    final facultyLatLng = LatLng(
      faculty.location!.latitude,
      faculty.location!.longitude,
    );
    
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: facultyLatLng,
          zoom: 18.5, // Closer zoom for better visibility
          tilt: 45.0,
          bearing: 0.0,
        ),
      ),
    );
  }
  
  // ignore: unused_element
  void _enable3DBuildings() {
    // Add 3D building extrusion layer if the style supports it
    // Only works with vector tile styles that include a "building" source
    // Our satellite raster style does not have building data, so wrap in try-catch
    try {
      _mapController?.addLayer(
        'building',
        'building-3d',
        const FillExtrusionLayerProperties(
          fillExtrusionColor: '#E8A87C', // Peach color matching theme
          fillExtrusionHeight: [
            'interpolate',
            ['linear'],
            ['zoom'],
            15, 0,
            16, ['get', 'height'],
          ],
          fillExtrusionBase: [
            'interpolate',
            ['linear'],
            ['zoom'],
            15, 0,
            16, ['get', 'min_height'],
          ],
          fillExtrusionOpacity: 0.8,
        ),
      );
    } catch (e) {
      debugPrint('3D buildings not available with current map style: $e');
    }
  }
  
  Future<void> _updateFacultyMarkers() async {
    if (_mapController == null || !_mapReady || _isDisposed || !mounted) return;
    
    // Clear existing circles
    for (final circle in _facultyCircles.values) {
      if (_isDisposed || !mounted) return;
      try {
        await _mapController?.removeCircle(circle);
      } catch (e) {
        debugPrint('Error removing circle: $e');
      }
    }
    _facultyCircles.clear();
    
    // Add new faculty markers as circles (show ALL online faculty with locations)
    if (widget.faculty != null) {
      for (final faculty in widget.faculty!) {
        // Show markers for ALL online faculty with location
        // Teachers can manually pin their location anywhere (e.g., "on the way")
        // or be tracked via GPS - show their actual set location
        if (faculty.isOnline && faculty.location != null) {
          final colorHex = _getStatusColor(faculty.user.currentStatus ?? 'offline');
          
          // Highlight selected faculty with a different style
          final isSelected = widget.selectedFaculty?.user.id == faculty.user.id;
          
          if (_isDisposed || !mounted) return;
          try {
            final circle = await _mapController?.addCircle(
              CircleOptions(
                geometry: LatLng(
                  faculty.location!.latitude,
                  faculty.location!.longitude,
                ),
                circleRadius: isSelected ? 16.0 : 12.0, // Larger for selected
                circleColor: colorHex,
                circleStrokeColor: isSelected ? '#FFD700' : '#FFFFFF', // Gold highlight for selected
                circleStrokeWidth: isSelected ? 5.0 : 3.0,
                circleOpacity: 1.0,
              ),
            );
            
            if (circle != null) {
              _facultyCircles[faculty.user.id] = circle;
            }
          } catch (e) {
            debugPrint('Error adding faculty circle: $e');
          }
        }
      }
    }
    
    debugPrint('3D Map: Added ${_facultyCircles.length} faculty markers');
  }
  
  Future<void> _updateUserLocationMarker() async {
    if (_mapController == null || !_mapReady || _isDisposed || !mounted) return;
    
    // Remove existing user marker
    if (_userLocationCircle != null) {
      try {
        await _mapController?.removeCircle(_userLocationCircle!);
      } catch (e) {
        debugPrint('Error removing user circle: $e');
      }
      _userLocationCircle = null;
    }
    
    if (_isDisposed || !mounted) return;
    
    // Add new user location marker
    if (widget.userLocation != null) {
      try {
        _userLocationCircle = await _mapController?.addCircle(
          CircleOptions(
            geometry: widget.userLocation!,
            circleRadius: 10.0,
            circleColor: '#2196F3', // Blue for user
            circleStrokeColor: '#FFFFFF',
            circleStrokeWidth: 3.0,
            circleOpacity: 1.0,
          ),
        );
      } catch (e) {
        debugPrint('Error adding user circle: $e');
      }
    }
  }
  
  String _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available for consultation':
      case 'available':
      case 'online':
        return '#41B3A3'; // Sage green
      case 'in a class':
      case 'teaching':
        return '#6EB5A0'; // Teal
      case 'in a meeting':
      case 'meeting':
        return '#C38D9E'; // Dusty rose
      case 'busy':
      case 'do not disturb':
        return '#E8A87C'; // Peach
      default:
        return '#8D8D8D'; // Gray
    }
  }
  
  void _centerOnCampus() {
    if (_isDisposed || !mounted || _mapController == null) return;
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _campusCenter,
          zoom: 17.0,
          tilt: 45.0,
          bearing: 0.0,
        ),
      ),
    );
  }
  
  void _centerOnUser() {
    if (_isDisposed || !mounted || _mapController == null) return;
    if (widget.userLocation != null) {
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: widget.userLocation!,
            zoom: 18.0,
            tilt: 45.0,
            bearing: 0.0,
          ),
        ),
      );
    }
  }
  
  void _toggle3DView() {
    if (_isDisposed || !mounted || _mapController == null) return;
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _campusCenter,
          zoom: 17.0,
          tilt: 60.0, // More dramatic tilt
          bearing: 45.0, // Rotate view
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Stack(
      children: [
        // MapLibre GL Map - wrapped in RepaintBoundary for isolation
        RepaintBoundary(
          child: MapLibreMap(
            key: _mapKey,
            onMapCreated: _onMapCreated,
            onStyleLoadedCallback: _onStyleLoaded,
            initialCameraPosition: CameraPosition(
              target: _campusCenter,
              zoom: 17.0,
              tilt: 45.0,
            ),
            styleString: _buildMapStyle(includeBoundaries: widget.showCampusBoundary),
            myLocationEnabled: true,
            myLocationTrackingMode: MyLocationTrackingMode.none,
            trackCameraPosition: true,
            compassEnabled: true,
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: true,
          ),
        ),
        
        // Loading indicator
        if (!_mapReady)
          Container(
            color: AppColors.background.withValues(alpha: 0.8),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: AppColors.primary,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading 3D Campus Map...',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        
        // Map controls
        Positioned(
          right: 16,
          bottom: 100,
          child: Column(
            children: [
              // 3D View toggle
              _MapButton(
                icon: Icons.threed_rotation,
                onPressed: _toggle3DView,
                tooltip: '3D View',
              ),
              const SizedBox(height: 8),
              // Center on campus
              _MapButton(
                icon: Icons.school,
                onPressed: _centerOnCampus,
                tooltip: 'Campus Center',
              ),
              const SizedBox(height: 8),
              // Center on user
              _MapButton(
                icon: Icons.my_location,
                onPressed: _centerOnUser,
                tooltip: 'My Location',
              ),
            ],
          ),
        ),
        
        // Campus info banner
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.location_city,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppConstants.campusName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        AppConstants.campusLocation,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '3D',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Map control button widget
class _MapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  
  const _MapButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });
  
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
