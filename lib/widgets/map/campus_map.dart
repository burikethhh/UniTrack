import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/map_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../models/models.dart';

/// 2D Campus map widget using flutter_map with legal tile providers.
///
/// Uses MapTiler raster tiles when an API key is configured, otherwise
/// falls back to free OSM streets + ESRI satellite imagery.
class CampusMap extends StatefulWidget {
  final List<FacultyWithLocation>? faculty;
  final LatLng? userLocation;
  final LatLng? selectedLocation;
  final FacultyWithLocation? selectedFaculty;
  final Function(FacultyWithLocation)? onMarkerTap;
  final bool showCampusBoundary;
  final bool showRoute;
  final List<LatLng>? routePoints;
  final String? campusId;
  final bool showSatellite;
  final Function(TapPosition, LatLng)? onTap;
  final MapController? externalController;

  /// Optional custom marker builder for individual faculty markers.
  /// If provided, overrides the default initials-circle marker.
  final Widget Function(FacultyWithLocation faculty, bool isSelected)?
  customMarkerBuilder;

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
    this.showSatellite = true,
    this.onTap,
    this.externalController,
    this.customMarkerBuilder,
  });

  @override
  CampusMapState createState() => CampusMapState();
}

class CampusMapState extends State<CampusMap> with TickerProviderStateMixin {
  late final MapController _mapController;
  AnimationController? _flyController;
  double _currentZoom = 17.0;

  // Smooth marker movement: cache previous positions
  final Map<String, LatLng> _prevPositions = {};
  final Map<String, LatLng> _targetPositions = {};
  AnimationController? _markerAnimController;
  double _markerAnimValue = 1.0;

  // Cached campus boundary polygons — boundaries never change at runtime,
  // so we compute once and reuse across rebuilds (avoids re-parsing hex
  // colours and allocating Polygon objects at 60fps during marker animation).
  List<Polygon>? _cachedBoundaryPolygons;

  @override
  void initState() {
    super.initState();
    _mapController = widget.externalController ?? MapController();
  }

  @override
  void dispose() {
    _flyController?.stop();
    _flyController?.dispose();
    _markerAnimController?.stop();
    _markerAnimController?.dispose();
    super.dispose();
  }

  LatLng get _campusCenter {
    final campusId = widget.campusId ?? AppConstants.defaultCampusId;
    final center = AppConstants.getCampusCenter(campusId);
    if (center != null) return LatLng(center[0], center[1]);
    return LatLng(AppConstants.campusCenterLat, AppConstants.campusCenterLng);
  }

  LatLng get _initialCenter {
    if (widget.selectedFaculty?.location != null) {
      return widget.selectedFaculty!.location!.latLng;
    }
    return _campusCenter;
  }

  @override
  void didUpdateWidget(CampusMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Campus changed — fly to new campus center
    if (widget.campusId != oldWidget.campusId) {
      animateToCampus(widget.campusId);
    }
    // Selected faculty changed — fly to their location
    if (widget.selectedFaculty != oldWidget.selectedFaculty &&
        widget.selectedFaculty?.location != null) {
      flyTo(widget.selectedFaculty!.location!.latLng, 18.5);
    }
    // Smooth marker movement — detect position changes
    _animateMarkerPositions();
  }

  /// Detect faculty position changes and start smooth interpolation
  void _animateMarkerPositions() {
    if (widget.faculty == null) return;
    bool hasChange = false;

    for (final f in widget.faculty!) {
      if (f.location == null) continue;
      final id = f.user.id;
      final newPos = f.location!.latLng;
      final oldPos = _targetPositions[id];

      if (oldPos != null &&
          (oldPos.latitude != newPos.latitude ||
              oldPos.longitude != newPos.longitude)) {
        // Use the current *visual* position (interpolated) as the starting
        // point so that interrupting an in-progress animation doesn't snap
        // the marker forward to the old target.
        _prevPositions[id] = _interpolatedPosition(id, oldPos);
        hasChange = true;
      } else if (oldPos == null) {
        _prevPositions[id] = newPos; // first time — no animation
      }
      _targetPositions[id] = newPos;
    }

    if (hasChange) {
      _markerAnimController?.stop();
      _markerAnimController?.dispose();
      _markerAnimController = AnimationController(
        duration: const Duration(milliseconds: 800),
        vsync: this,
      );
      _markerAnimValue = 0.0;
      _markerAnimController!.addListener(() {
        if (mounted) {
          setState(() => _markerAnimValue = _markerAnimController!.value);
        }
      });
      _markerAnimController!.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          // Finalize positions
          _prevPositions.addAll(_targetPositions);
          _markerAnimValue = 1.0;
        }
      });
      _markerAnimController!.forward();
    }
  }

  /// Get the interpolated position for a faculty member
  LatLng _interpolatedPosition(String userId, LatLng target) {
    if (_markerAnimValue >= 1.0) return target;
    final prev = _prevPositions[userId];
    if (prev == null) return target;
    final t = Curves.easeInOut.transform(_markerAnimValue);
    return LatLng(
      prev.latitude + (target.latitude - prev.latitude) * t,
      prev.longitude + (target.longitude - prev.longitude) * t,
    );
  }

  // ──────────────────────────────────────────────────────────
  //  Tile layers based on provider availability
  // ──────────────────────────────────────────────────────────

  List<Widget> _buildTileLayers() {
    if (widget.showSatellite) {
      if (MapConstants.hasMapTilerKey) {
        // MapTiler hybrid satellite (imagery + labels)
        return [
          TileLayer(
            urlTemplate: MapConstants.mapTilerSatelliteRasterUrl,
            userAgentPackageName: 'com.sksu.unitrack',
            maxZoom: 20,
          ),
        ];
      }
      // Free ESRI satellite + transport labels overlay
      return [
        TileLayer(
          urlTemplate: MapConstants.esriSatelliteUrl,
          userAgentPackageName: 'com.sksu.unitrack',
          maxZoom: 19,
          additionalOptions: const {
            'attribution': MapConstants.esriAttribution,
          },
        ),
        TileLayer(
          urlTemplate: MapConstants.esriHybridUrl,
          userAgentPackageName: 'com.sksu.unitrack',
          maxZoom: 19,
        ),
      ];
    }

    // Streets mode
    if (MapConstants.hasMapTilerKey) {
      return [
        TileLayer(
          urlTemplate: MapConstants.mapTilerRasterUrl,
          userAgentPackageName: 'com.sksu.unitrack',
          maxZoom: 20,
        ),
      ];
    }
    return [
      TileLayer(
        urlTemplate: MapConstants.osmTileUrl,
        userAgentPackageName: 'com.sksu.unitrack',
        maxZoom: 19,
        additionalOptions: const {'attribution': MapConstants.osmAttribution},
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _initialCenter,
        initialZoom: widget.selectedFaculty != null ? 18.5 : 17.0,
        minZoom: 5.0,
        maxZoom: 19.0,
        onTap: widget.onTap ?? (_, _) {},
        onMapEvent: _onMapEvent,
      ),
      children: [
        // Tile layers (satellite or streets)
        ..._buildTileLayers(),

        // Campus boundary polygons for ALL 7 campuses
        if (widget.showCampusBoundary)
          PolygonLayer(
            polygons: _cachedBoundaryPolygons ??= _buildAllCampusBoundaries(),
          ),

        // Route polyline
        if (widget.showRoute && widget.routePoints != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: widget.routePoints!,
                color: AppColors.mapRoute,
                strokeWidth: 5,
                pattern: const StrokePattern.dotted(),
              ),
            ],
          ),

        // Faculty markers
        if (widget.faculty != null)
          MarkerLayer(markers: _buildFacultyMarkers()),

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

  /// Build faculty markers — clusters when zoomed out with many markers
  List<Marker> _buildFacultyMarkers() {
    if (widget.faculty == null) return [];

    // When a customMarkerBuilder is provided, the caller already filtered
    // the list (e.g. admin's _applyFilter). Only require a non-null location.
    // Otherwise use the stricter isOnline check (requires isWithinCampus).
    final online = widget.customMarkerBuilder != null
        ? widget.faculty!.where((f) => f.location != null).toList()
        : widget.faculty!
              .where((f) => f.isOnline && f.location != null)
              .toList();

    // Cluster when zoomed out and many markers visible
    if (_currentZoom < 15 && online.length > 8) {
      return _buildClusteredMarkers(online);
    }

    return online.map((f) => _buildSingleFacultyMarker(f)).toList();
  }

  /// Build a single faculty marker — uses customMarkerBuilder if provided
  Marker _buildSingleFacultyMarker(FacultyWithLocation faculty) {
    final isSelected = widget.selectedFaculty?.user.id == faculty.user.id;
    final point = _interpolatedPosition(
      faculty.user.id,
      faculty.location!.latLng,
    );
    final markerSize = isSelected ? 54.0 : 44.0;

    if (widget.customMarkerBuilder != null) {
      return Marker(
        point: point,
        width: markerSize,
        height: markerSize,
        child: GestureDetector(
          onTap: () => widget.onMarkerTap?.call(faculty),
          child: widget.customMarkerBuilder!(faculty, isSelected),
        ),
      );
    }

    final color = AppColors.getStatusColor(faculty.displayStatus);
    return Marker(
      point: point,
      width: markerSize,
      height: markerSize,
      child: GestureDetector(
        onTap: () => widget.onMarkerTap?.call(faculty),
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
  }

  /// Cluster nearby markers into a single cluster marker
  List<Marker> _buildClusteredMarkers(List<FacultyWithLocation> users) {
    final clusters = <_CampusMapCluster>[];
    final used = <int>{};
    final clusterRadius = 0.002 * (18 - _currentZoom).clamp(1, 10);

    for (int i = 0; i < users.length; i++) {
      if (used.contains(i)) continue;
      final cluster = [users[i]];
      used.add(i);

      for (int j = i + 1; j < users.length; j++) {
        if (used.contains(j)) continue;
        final dx =
            users[i].location!.latLng.latitude -
            users[j].location!.latLng.latitude;
        final dy =
            users[i].location!.latLng.longitude -
            users[j].location!.latLng.longitude;
        if (sqrt(dx * dx + dy * dy) < clusterRadius) {
          cluster.add(users[j]);
          used.add(j);
        }
      }
      clusters.add(_CampusMapCluster(cluster));
    }

    return clusters.map((cluster) {
      if (cluster.users.length == 1) {
        return _buildSingleFacultyMarker(cluster.users.first);
      }

      // Cluster bubble
      return Marker(
        point: cluster.center,
        width: 52,
        height: 52,
        child: GestureDetector(
          onTap: () {
            // Zoom in to break the cluster
            flyTo(cluster.center, _currentZoom + 2);
          },
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
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

  /// Track zoom changes for clustering decisions
  void _onMapEvent(MapEvent event) {
    if (event is MapEventMove || event is MapEventMoveEnd) {
      final newZoom = _mapController.camera.zoom;
      if ((newZoom - _currentZoom).abs() > 0.3) {
        setState(() => _currentZoom = newZoom);
      }
    }
  }

  /// Build polygon boundaries for ALL 7 SKSU campuses
  List<Polygon> _buildAllCampusBoundaries() {
    final List<Polygon> polygons = [];

    for (final campus in AppConstants.campusesData) {
      final campusId = campus['id'] as String;
      final boundary = campus['boundaryPoints'] as List;

      // Parse hex color from MapConstants
      final hexColor = MapConstants.campusBoundaryColors[campusId] ?? '#41B3A3';
      final color = _parseHexColor(hexColor);

      final points = boundary
          .map<LatLng>(
            (point) => LatLng((point as List)[0] as double, point[1] as double),
          )
          .toList();

      polygons.add(
        Polygon(
          points: points,
          color: color.withValues(alpha: 0.15),
          borderColor: color,
          borderStrokeWidth: 2.5,
        ),
      );
    }

    return polygons;
  }

  static Color _parseHexColor(String hex) {
    final hexCode = hex.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }

  // ──────────────────────────────────────────────────────────
  //  Public navigation controls
  // ──────────────────────────────────────────────────────────

  /// Animated fly-to a campus center.
  void animateToCampus([String? campusId]) {
    final id = campusId ?? widget.campusId ?? AppConstants.defaultCampusId;
    final center = AppConstants.getCampusCenter(id);
    if (center == null) return;
    flyTo(LatLng(center[0], center[1]), 17.0);
  }

  /// Animated fly-to with zoom-dip effect.
  /// The camera zooms out proportionally to the travel distance, pans
  /// smoothly, then zooms back in — producing a "fly over" feel.
  void flyTo(LatLng target, double targetZoom) {
    _flyController?.stop();
    _flyController?.dispose();
    _flyController = null;

    final startCenter = _mapController.camera.center;
    final startZoom = _mapController.camera.zoom;

    // Distance in degrees (rough)
    final dLat = (target.latitude - startCenter.latitude).abs();
    final dLng = (target.longitude - startCenter.longitude).abs();
    final maxD = max(dLat, dLng);

    // Very close — just snap
    if (maxD < 0.001) {
      _mapController.move(target, targetZoom);
      return;
    }

    // Determine zoom-out depth and duration based on distance
    double minZoom;
    int durationMs;
    if (maxD < 0.01) {
      minZoom = 15.0;
      durationMs = 600;
    } else if (maxD < 0.05) {
      minZoom = 13.0;
      durationMs = 900;
    } else if (maxD < 0.2) {
      minZoom = 10.0;
      durationMs = 1200;
    } else if (maxD < 0.5) {
      minZoom = 8.0;
      durationMs = 1500;
    } else {
      minZoom = 6.0;
      durationMs = 1800;
    }

    // Ensure minZoom is lower than both start and target
    minZoom = min(minZoom, min(startZoom, targetZoom) - 1.5);

    _flyController = AnimationController(
      duration: Duration(milliseconds: durationMs),
      vsync: this,
    );

    final curved = CurvedAnimation(
      parent: _flyController!,
      curve: Curves.easeInOutCubic,
    );

    curved.addListener(() {
      if (!mounted) return;
      final t = curved.value;

      // Position: smooth interpolation
      final lat =
          startCenter.latitude + (target.latitude - startCenter.latitude) * t;
      final lng =
          startCenter.longitude +
          (target.longitude - startCenter.longitude) * t;

      // Zoom: two-phase dip — out then in
      double z;
      if (t <= 0.45) {
        final p = t / 0.45;
        z = startZoom + (minZoom - startZoom) * Curves.easeOut.transform(p);
      } else {
        final p = (t - 0.45) / 0.55;
        z = minZoom + (targetZoom - minZoom) * Curves.easeIn.transform(p);
      }

      _mapController.move(LatLng(lat, lng), z.clamp(3.0, 19.0));
    });

    _flyController!.forward();
  }

  /// Fit bounds to show route
  void fitRoute() {
    if (widget.routePoints != null && widget.routePoints!.isNotEmpty) {
      final bounds = LatLngBounds.fromPoints(widget.routePoints!);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
      );
    }
  }
}

/// Helper class for marker clustering within CampusMap
class _CampusMapCluster {
  final List<FacultyWithLocation> users;

  _CampusMapCluster(this.users);

  LatLng get center {
    double lat = 0, lng = 0;
    for (final u in users) {
      lat += u.location!.latLng.latitude;
      lng += u.location!.latLng.longitude;
    }
    return LatLng(lat / users.length, lng / users.length);
  }
}
