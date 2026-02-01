import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../models/models.dart';

/// Campus map widget using OpenStreetMap
class CampusMap extends StatefulWidget {
  final List<FacultyWithLocation>? faculty;
  final LatLng? userLocation;
  final LatLng? selectedLocation;
  final FacultyWithLocation? selectedFaculty; // Faculty to focus on
  final Function(FacultyWithLocation)? onMarkerTap;
  final bool showCampusBoundary;
  final bool showRoute;
  final List<LatLng>? routePoints;
  final String? campusId; // Campus to display (defaults to Isulan)
  
  const CampusMap({
    super.key,
    this.faculty,
    this.userLocation,
    this.selectedLocation,
    this.selectedFaculty,
    this.onMarkerTap,
    this.showCampusBoundary = true,
    this.showRoute = false,
    this.routePoints,
    this.campusId,
  });
  
  @override
  State<CampusMap> createState() => _CampusMapState();
}

class _CampusMapState extends State<CampusMap> {
  final MapController _mapController = MapController();
  
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
  
  // Get initial center - prefer selected faculty location
  LatLng get _initialCenter {
    if (widget.selectedFaculty?.location != null) {
      return widget.selectedFaculty!.location!.latLng;
    }
    return _campusCenter;
  }
  
  @override
  void didUpdateWidget(CampusMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Center on selected faculty when it changes
    if (widget.selectedFaculty != oldWidget.selectedFaculty && 
        widget.selectedFaculty?.location != null) {
      _mapController.move(widget.selectedFaculty!.location!.latLng, 18.5);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _initialCenter,
        initialZoom: widget.selectedFaculty != null ? 18.5 : 17.0,
        minZoom: 14.0,
        maxZoom: 19.0,
        onTap: (_, __) {
          // Dismiss any popups
        },
      ),
      children: [
        // Satellite Tile Layer (Google Maps Satellite)
        TileLayer(
          urlTemplate: 'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}',
          userAgentPackageName: 'com.sksu.unitrack',
          maxZoom: 20,
        ),
        // Road labels overlay for better navigation
        TileLayer(
          urlTemplate: 'https://mt1.google.com/vt/lyrs=h&x={x}&y={y}&z={z}',
          userAgentPackageName: 'com.sksu.unitrack',
          maxZoom: 20,
        ),
        
        // All campus boundary polygons (show all 3 SKSU campuses)
        if (widget.showCampusBoundary)
          PolygonLayer(
            polygons: _buildAllCampusBoundaries(),
          ),
        
        // Route polyline
        if (widget.showRoute && widget.routePoints != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: widget.routePoints!,
                color: AppColors.mapRoute,
                strokeWidth: 4,
              ),
            ],
          ),
        
        // Faculty markers
        if (widget.faculty != null)
          MarkerLayer(
            markers: _buildFacultyMarkers(),
          ),
        
        // User location marker
        if (widget.userLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: widget.userLocation!,
                width: 30,
                height: 30,
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
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        
        // Selected location marker (destination)
        if (widget.selectedLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: widget.selectedLocation!,
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.location_on,
                  color: AppColors.accent,
                  size: 40,
                ),
              ),
            ],
          ),
      ],
    );
  }
  
  /// Build faculty markers - show ALL online faculty with locations
  /// Teachers can set their location manually or via GPS - always show their set location
  List<Marker> _buildFacultyMarkers() {
    if (widget.faculty == null) return [];
    
    // Show ALL online faculty with location
    // This includes manually pinned locations (e.g., "on the way to building X")
    return widget.faculty!
        .where((f) => f.isOnline && f.location != null)
        .map((faculty) {
      final color = AppColors.getStatusColor(faculty.displayStatus);
      final isSelected = widget.selectedFaculty?.user.id == faculty.user.id;
      
      return Marker(
        point: faculty.location!.latLng,
        width: isSelected ? 54 : 44,
        height: isSelected ? 54 : 44,
        child: GestureDetector(
          onTap: () {
            widget.onMarkerTap?.call(faculty);
          },
          child: Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.amber : Colors.white, 
                width: isSelected ? 4 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected 
                      ? Colors.amber.withValues(alpha: 0.6)
                      : color.withValues(alpha: 0.4),
                  blurRadius: isSelected ? 12 : 6,
                  spreadRadius: isSelected ? 3 : 1,
                ),
              ],
            ),
            child: Center(
              child: Text(
                faculty.user.initials,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSelected ? 14 : 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
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
  
  /// Center on campus
  void centerOnCampus() {
    _mapController.move(_campusCenter, 17.0);
  }
  
  /// Center on specific location
  void centerOn(LatLng location, {double zoom = 18.0}) {
    _mapController.move(location, zoom);
  }
  
  /// Fit bounds to show route
  void fitRoute() {
    if (widget.routePoints != null && widget.routePoints!.isNotEmpty) {
      final bounds = LatLngBounds.fromPoints(widget.routePoints!);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(50),
        ),
      );
    }
  }
}
