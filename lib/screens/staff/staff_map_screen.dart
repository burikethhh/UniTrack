import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/providers.dart';

/// Staff map screen with manual location pinning and 3D support
class StaffMapScreen extends StatefulWidget {
  final bool use3D;
  final bool useManualPin;
  
  const StaffMapScreen({
    super.key,
    this.use3D = false,
    this.useManualPin = false,
  });
  
  @override
  State<StaffMapScreen> createState() => _StaffMapScreenState();
}

class _StaffMapScreenState extends State<StaffMapScreen> {
  final MapController _mapController = MapController();
  maplibre.MapLibreMapController? _maplibreController;
  LatLng? _manualPinLocation;
  LatLng? _currentGpsLocation;
  late bool _useManualPin;
  late bool _use3D;
  bool _map3DReady = false;
  maplibre.Circle? _locationCircle;
  
  // Get campus center based on user's campus
  LatLng get _campusCenter {
    final authProvider = context.read<AuthProvider>();
    final campusId = authProvider.user?.campusId ?? AppConstants.defaultCampusId;
    final center = AppConstants.getCampusCenter(campusId);
    if (center != null) {
      return LatLng(center[0], center[1]);
    }
    return LatLng(AppConstants.campusCenterLat, AppConstants.campusCenterLng);
  }
  
  // Satellite map style for 3D view
  static const String _mapStyle = '''
{
  "version": 8,
  "name": "SKSU Campus Satellite",
  "sources": {
    "satellite": {
      "type": "raster",
      "tiles": ["https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}"],
      "tileSize": 256,
      "maxzoom": 20
    }
  },
  "layers": [
    {
      "id": "satellite-layer",
      "type": "raster",
      "source": "satellite"
    }
  ]
}
''';
  
  @override
  void initState() {
    super.initState();
    _useManualPin = widget.useManualPin;
    _use3D = widget.use3D;
    _getCurrentLocation();
  }
  
  Future<void> _getCurrentLocation() async {
    final locationProvider = context.read<LocationProvider>();
    final position = await locationProvider.getCurrentPosition();
    if (position != null && mounted) {
      setState(() {
        _currentGpsLocation = LatLng(position.latitude, position.longitude);
      });
      // Update 3D map location circle if applicable
      if (_use3D && _map3DReady && _maplibreController != null) {
        _update3DLocationMarker();
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_use3D ? '3D Campus View' : 'My Location'),
        actions: [
          // Toggle 2D/3D
          IconButton(
            icon: Icon(_use3D ? Icons.map : Icons.view_in_ar),
            onPressed: () {
              setState(() {
                _use3D = !_use3D;
                _map3DReady = false;
              });
            },
            tooltip: _use3D ? 'Switch to 2D Map' : 'Switch to 3D View',
          ),
          // Toggle between GPS and Manual (only for 2D)
          if (!_use3D)
            IconButton(
              icon: Icon(_useManualPin ? Icons.gps_off : Icons.gps_fixed),
              onPressed: () {
                setState(() {
                  _useManualPin = !_useManualPin;
                });
                if (!_useManualPin) {
                  _manualPinLocation = null;
                }
              },
              tooltip: _useManualPin ? 'Use GPS Location' : 'Manual Pin Mode',
            ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
            tooltip: 'Refresh Location',
          ),
        ],
      ),
      body: Stack(
        children: [
          // 3D Map or 2D Map based on toggle
          if (_use3D)
            _build3DMap()
          else
            _build2DMap(),
          
          // Mode indicator (top info card)
          _buildModeIndicator(),
          
          // Campus legend (bottom left)
          _buildCampusLegend(),
          
          // Location info panel (for manual pin)
          if (!_use3D && _useManualPin && _manualPinLocation != null)
            _buildPinInfoPanel(),
          
          // 3D loading overlay
          if (_use3D && !_map3DReady)
            Container(
              color: AppColors.background.withValues(alpha: 0.8),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
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
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }
  
  /// Build campus legend overlay
  Widget _buildCampusLegend() {
    return Positioned(
      left: 12,
      bottom: 16,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'SKSU Campuses',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            _buildLegendItem(AppColors.primary, 'Isulan'),
            _buildLegendItem(Colors.orange, 'Tacurong'),
            _buildLegendItem(Colors.purple, 'ACCESS'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLegendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.3),
              border: Border.all(color: color, width: 1.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
  
  /// Build 2D FlutterMap
  Widget _build2DMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentGpsLocation ?? _campusCenter,
        initialZoom: 17.0,
        minZoom: 10.0,
        maxZoom: 20.0,
        onTap: _useManualPin ? (tapPos, latLng) {
          setState(() {
            _manualPinLocation = latLng;
          });
        } : null,
      ),
      children: [
        // Satellite Tile Layer
        TileLayer(
          urlTemplate: 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
          userAgentPackageName: 'com.sksu.unitrack',
          maxZoom: 20,
        ),
        
        // All campus boundaries (show all 3 SKSU campuses)
        PolygonLayer(
          polygons: _buildAllCampusBoundaries(),
        ),
        
        // GPS Location marker (blue)
        if (_currentGpsLocation != null && !_useManualPin)
          MarkerLayer(
            markers: [
              Marker(
                point: _currentGpsLocation!,
                width: 40,
                height: 40,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        
        // Manual Pin marker (red/accent)
        if (_manualPinLocation != null && _useManualPin)
          MarkerLayer(
            markers: [
              Marker(
                point: _manualPinLocation!,
                width: 50,
                height: 50,
                child: const Icon(
                  Icons.location_on,
                  color: AppColors.accent,
                  size: 50,
                ),
              ),
            ],
          ),
      ],
    );
  }
  
  /// Build 3D MapLibre map
  Widget _build3DMap() {
    return maplibre.MapLibreMap(
      onMapCreated: (controller) {
        _maplibreController = controller;
      },
      onStyleLoadedCallback: () async {
        setState(() {
          _map3DReady = true;
        });
        // Add location marker
        await _update3DLocationMarker();
        // Add campus boundary
        await _add3DCampusBoundary();
        // Animate to tilted view
        _maplibreController?.animateCamera(
          maplibre.CameraUpdate.newCameraPosition(
            maplibre.CameraPosition(
              target: maplibre.LatLng(
                _currentGpsLocation?.latitude ?? _campusCenter.latitude,
                _currentGpsLocation?.longitude ?? _campusCenter.longitude,
              ),
              zoom: 17.0,
              tilt: 45.0,
              bearing: 0.0,
            ),
          ),
        );
      },
      initialCameraPosition: maplibre.CameraPosition(
        target: maplibre.LatLng(
          _currentGpsLocation?.latitude ?? _campusCenter.latitude,
          _currentGpsLocation?.longitude ?? _campusCenter.longitude,
        ),
        zoom: 17.0,
        tilt: 45.0,
      ),
      styleString: _mapStyle,
      myLocationEnabled: true,
      myLocationTrackingMode: maplibre.MyLocationTrackingMode.none,
      compassEnabled: true,
      rotateGesturesEnabled: true,
      tiltGesturesEnabled: true,
    );
  }
  
  /// Update 3D location marker
  Future<void> _update3DLocationMarker() async {
    if (_maplibreController == null || !_map3DReady) return;
    
    // Remove existing marker
    if (_locationCircle != null) {
      try {
        await _maplibreController?.removeCircle(_locationCircle!);
      } catch (e) {
        debugPrint('Error removing circle: $e');
      }
      _locationCircle = null;
    }
    
    // Add new marker if we have a location
    if (_currentGpsLocation != null) {
      try {
        _locationCircle = await _maplibreController?.addCircle(
          maplibre.CircleOptions(
            geometry: maplibre.LatLng(
              _currentGpsLocation!.latitude,
              _currentGpsLocation!.longitude,
            ),
            circleRadius: 12.0,
            circleColor: '#41B3A3',
            circleStrokeColor: '#FFFFFF',
            circleStrokeWidth: 3.0,
            circleOpacity: 1.0,
          ),
        );
      } catch (e) {
        debugPrint('Error adding location circle: $e');
      }
    }
  }
  
  /// Add ALL campus boundaries to 3D map (all 3 SKSU campuses)
  Future<void> _add3DCampusBoundary() async {
    if (_maplibreController == null) return;
    
    // Campus colors for distinction
    final campusColors = {
      'isulan': '#E8A87C',    // Peach (primary)
      'tacurong': '#FF9800',  // Orange
      'access': '#9C27B0',    // Purple
    };
    
    for (final campus in AppConstants.campusesData) {
      final campusId = campus['id'] as String;
      final boundary = campus['boundaryPoints'] as List;
      final color = campusColors[campusId] ?? '#E8A87C';
      
      final boundaryPoints = boundary
          .map<maplibre.LatLng>((point) => maplibre.LatLng(
                (point as List)[0] as double,
                point[1] as double,
              ))
          .toList();
      
      // Close the polygon
      if (boundaryPoints.isNotEmpty) {
        boundaryPoints.add(boundaryPoints.first);
      }
      
      try {
        await _maplibreController?.addLine(
          maplibre.LineOptions(
            geometry: boundaryPoints,
            lineColor: color,
            lineWidth: 3.0,
            lineOpacity: 0.9,
          ),
        );
      } catch (e) {
        debugPrint('Error adding boundary for $campusId: $e');
      }
    }
  }
  
  /// Build mode indicator card
  Widget _buildModeIndicator() {
    final locationProvider = context.watch<LocationProvider>();
    final isManualPinActive = locationProvider.isManualPinMode;
    
    IconData icon;
    Color color;
    String title;
    String subtitle;
    
    if (_use3D) {
      icon = Icons.view_in_ar;
      color = AppColors.info;
      title = '3D Campus View';
      subtitle = 'Rotate and tilt to explore campus';
    } else if (isManualPinActive) {
      // Currently using a manually pinned location
      icon = Icons.push_pin;
      color = AppColors.accent;
      title = 'Manual Pin Active';
      subtitle = 'Location pinned - students can see you here';
    } else if (_useManualPin) {
      icon = Icons.touch_app;
      color = AppColors.accent;
      title = 'Manual Pin Mode';
      subtitle = 'Tap anywhere on the map to set your location';
    } else {
      icon = Icons.gps_fixed;
      color = AppColors.primary;
      title = 'GPS Tracking Mode';
      subtitle = 'Your location is tracked via GPS';
    }
    
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // Within campus indicator
            if (_currentGpsLocation != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _isWithinCampus(_currentGpsLocation!)
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isWithinCampus(_currentGpsLocation!)
                          ? Icons.check_circle
                          : Icons.warning,
                      color: _isWithinCampus(_currentGpsLocation!)
                          ? AppColors.success
                          : AppColors.warning,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isWithinCampus(_currentGpsLocation!) ? 'In' : 'Out',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _isWithinCampus(_currentGpsLocation!)
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  /// Build pin info panel
  Widget _buildPinInfoPanel() {
    return Positioned(
      bottom: 100,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, color: AppColors.accent, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Pinned Location',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isWithinCampus(_manualPinLocation!)
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isWithinCampus(_manualPinLocation!)
                            ? Icons.check_circle
                            : Icons.warning,
                        color: _isWithinCampus(_manualPinLocation!)
                            ? AppColors.success
                            : AppColors.warning,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isWithinCampus(_manualPinLocation!)
                            ? 'Within Campus'
                            : 'Outside Campus',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _isWithinCampus(_manualPinLocation!)
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Lat: ${_manualPinLocation!.latitude.toStringAsFixed(6)}, Lng: ${_manualPinLocation!.longitude.toStringAsFixed(6)}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Build FAB
  Widget _buildFAB() {
    return Consumer<LocationProvider>(
      builder: (context, locationProvider, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Set Manual Location Button (only for 2D + manual pin mode)
            if (!_use3D && _useManualPin && _manualPinLocation != null)
              FloatingActionButton.extended(
                heroTag: 'setManual',
                onPressed: () => _setManualLocation(locationProvider),
                icon: const Icon(Icons.check),
                label: const Text('Set This Location'),
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
              ),
            if (!_use3D && _useManualPin && _manualPinLocation != null)
              const SizedBox(height: 12),
            // Switch to Auto GPS button (only visible when in manual pin mode)
            if (locationProvider.isManualPinMode)
              FloatingActionButton.extended(
                heroTag: 'switchToAuto',
                onPressed: () async {
                  await locationProvider.switchToAutoTracking();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Switched to automatic GPS tracking'),
                        backgroundColor: AppColors.primary,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.gps_fixed),
                label: const Text('Use GPS'),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            if (locationProvider.isManualPinMode)
              const SizedBox(height: 12),
            // Center on campus button
            FloatingActionButton(
              heroTag: 'center',
              onPressed: () {
                if (_use3D && _maplibreController != null) {
                  _maplibreController?.animateCamera(
                    maplibre.CameraUpdate.newCameraPosition(
                      maplibre.CameraPosition(
                        target: maplibre.LatLng(
                          _campusCenter.latitude,
                          _campusCenter.longitude,
                        ),
                        zoom: 17.0,
                        tilt: 45.0,
                        bearing: 0.0,
                      ),
                    ),
                  );
                } else {
                  _mapController.move(_campusCenter, 17.0);
                }
              },
              backgroundColor: Colors.white,
              child: const Icon(Icons.center_focus_strong, color: AppColors.primary),
            ),
            const SizedBox(height: 12),
            // Show all campuses button (zoom out to see all 3)
            FloatingActionButton.small(
              heroTag: 'allCampuses',
              onPressed: _showAllCampuses,
              backgroundColor: Colors.white,
              child: const Icon(Icons.zoom_out_map, color: AppColors.primaryDark),
            ),
          ],
        );
      },
    );
  }
  
  /// Zoom out to show all 3 SKSU campuses
  void _showAllCampuses() {
    // Center point between all 3 campuses (roughly in the middle)
    // Isulan: 6.6333, 124.6091
    // Tacurong: 6.691763, 124.67835
    // ACCESS: 6.668761, 124.62971
    const centerLat = 6.665; // Approximate center
    const centerLng = 124.645;
    const zoomLevel = 11.5; // Zoom out to see all campuses
    
    if (_use3D && _maplibreController != null) {
      _maplibreController?.animateCamera(
        maplibre.CameraUpdate.newCameraPosition(
          maplibre.CameraPosition(
            target: maplibre.LatLng(centerLat, centerLng),
            zoom: zoomLevel,
            tilt: 0.0,
            bearing: 0.0,
          ),
        ),
      );
    } else {
      _mapController.move(const LatLng(centerLat, centerLng), zoomLevel);
    }
    
    // Show info about the 3 campuses
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            const Text('Isulan', style: TextStyle(fontSize: 11)),
            const SizedBox(width: 12),
            Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.orange, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            const Text('Tacurong', style: TextStyle(fontSize: 11)),
            const SizedBox(width: 12),
            Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.purple, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            const Text('ACCESS', style: TextStyle(fontSize: 11)),
          ],
        ),
        duration: const Duration(seconds: 4),
        backgroundColor: Colors.black87,
      ),
    );
  }
  
  /// Build polygon boundaries for ALL 3 campuses
  List<Polygon> _buildAllCampusBoundaries() {
    final List<Polygon> polygons = [];
    
    // Campus colors for distinction
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
        color: color.withValues(alpha: 0.15),
        borderColor: color,
        borderStrokeWidth: 2.5,
      ));
    }
    
    return polygons;
  }

  /// Check if location is within ANY of the 3 SKSU campuses
  bool _isWithinCampus(LatLng location) {
    return _isWithinAnyCampus(location.latitude, location.longitude);
  }
  
  /// Check if position is within ANY SKSU campus (Isulan, Tacurong, or ACCESS)
  bool _isWithinAnyCampus(double latitude, double longitude) {
    for (final campus in AppConstants.campusesData) {
      final boundary = campus['boundaryPoints'] as List;
      if (_isInsidePolygon(latitude, longitude, boundary)) {
        return true;
      }
    }
    return false;
  }
  
  /// Point-in-polygon algorithm
  bool _isInsidePolygon(double latitude, double longitude, List boundary) {
    int intersections = 0;
    
    for (int i = 0; i < boundary.length; i++) {
      final j = (i + 1) % boundary.length;
      final point1 = boundary[i] as List;
      final point2 = boundary[j] as List;
      final xi = point1[1] as double; // longitude
      final yi = point1[0] as double; // latitude
      final xj = point2[1] as double; // longitude
      final yj = point2[0] as double; // latitude
      
      if (((yi > latitude) != (yj > latitude)) &&
          (longitude < (xj - xi) * (latitude - yi) / (yj - yi) + xi)) {
        intersections++;
      }
    }
    
    return intersections.isOdd;
  }
  
  Future<void> _setManualLocation(LocationProvider locationProvider) async {
    if (_manualPinLocation == null) return;
    
    // Update location in Firestore with manual pin
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) return;
    
    // Show confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_on, color: AppColors.accent),
            SizedBox(width: 8),
            Text('Set Manual Location'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This will broadcast your location as:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Latitude: ${_manualPinLocation!.latitude.toStringAsFixed(6)}',
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                  Text(
                    'Longitude: ${_manualPinLocation!.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  _isWithinCampus(_manualPinLocation!)
                      ? Icons.check_circle
                      : Icons.warning,
                  color: _isWithinCampus(_manualPinLocation!)
                      ? AppColors.success
                      : AppColors.warning,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  _isWithinCampus(_manualPinLocation!)
                      ? 'Within Campus Boundaries'
                      : 'Outside Campus Boundaries',
                  style: TextStyle(
                    color: _isWithinCampus(_manualPinLocation!)
                        ? AppColors.success
                        : AppColors.warning,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Confirm'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      // Start tracking with manual location
      await locationProvider.setManualLocation(
        _manualPinLocation!.latitude,
        _manualPinLocation!.longitude,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Manual location set successfully!'),
              ],
            ),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    }
  }
}
