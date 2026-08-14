import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/map_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../models/models.dart';

/// Comprehensive 3D campus map widget using MapLibre GL.
///
/// Supports multiple view modes: standard streets, satellite, 3D buildings,
/// and ground-level perspective. Uses MapTiler when available, with free
/// ESRI/OSM fallback.
class CampusMap3D extends StatefulWidget {
  final List<FacultyWithLocation>? faculty;
  final LatLng? userLocation;
  final LatLng? selectedLocation;
  final FacultyWithLocation? selectedFaculty;
  final Function(FacultyWithLocation)? onMarkerTap;
  final bool showCampusBoundary;
  final bool enable3DBuildings;
  final String? campusId;
  final bool focusOnSelected;
  final MapViewMode viewMode;
  final Function(LatLng)? onMapTap;
  final LatLng? pinnedLocation;

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
    this.viewMode = MapViewMode.buildings3D,
    this.onMapTap,
    this.pinnedLocation,
  });

  @override
  State<CampusMap3D> createState() => CampusMap3DState();
}

class CampusMap3DState extends State<CampusMap3D>
    with AutomaticKeepAliveClientMixin {
  MapLibreMapController? _mapController;
  // GeoJSON-based markers — no addCircle() JS interop needed
  static const _facultySourceId = 'faculty-markers-source';
  static const _facultyCircleLayerId = 'faculty-markers-circle';
  static const _facultyStrokeLayerId = 'faculty-markers-stroke';
  static const _selectedSourceId = 'selected-marker-source';
  static const _selectedCircleLayerId = 'selected-marker-circle';
  static const _selectedStrokeLayerId = 'selected-marker-stroke';
  static const _userLocSourceId = 'user-location-source';
  static const _userLocGlowLayerId = 'user-location-glow';
  static const _userLocDotLayerId = 'user-location-dot';
  bool _mapReady = false;
  bool _isDisposed = false;
  bool _loadTimedOut = false;
  Timer? _loadTimer;
  MapViewMode _currentMode = MapViewMode.buildings3D;
  bool _buildingsAdded = false;
  int _styleLoadGeneration = 0; // Cancels stale async _onStyleLoaded runs
  bool _routeAdded = false; // Track if a route line layer is on the map

  @override
  bool get wantKeepAlive => true;

  LatLng get _campusCenter {
    final campusId = widget.campusId ?? AppConstants.defaultCampusId;
    final center = AppConstants.getCampusCenter(campusId);
    if (center != null) return LatLng(center[0], center[1]);
    return LatLng(AppConstants.campusCenterLat, AppConstants.campusCenterLng);
  }

  // ──────────────────────────────────────────────────────────
  //  Style generation
  // ──────────────────────────────────────────────────────────

  /// Build a style string for the current mode, with campus boundaries
  /// AND marker sources/layers baked in for maximum reliability on web.
  ///
  /// IMPORTANT: All GeoJSON sources and circle layers are embedded directly
  /// in the style JSON rather than added at runtime via addGeoJsonSource() /
  /// addCircleLayer() because those JS interop calls silently fail or hang
  /// on Flutter web. By baking them in, MapLibre's WebGL engine creates
  /// them as part of the initial style parse — then we only need
  /// setGeoJsonSource() for data updates, which is reliable.
  String _buildStyle(MapViewMode mode) {
    // Return the base style as-is. We used to bake GeoJSON sources and
    // circle layers into the style JSON, but MapLibre GL JS on web throws
    // parse errors ("Cannot read properties of undefined") when it encounters
    // the baked-in sources. Instead, all sources/layers are added at runtime
    // in _onStyleLoaded() with try-catch guards.
    return MapConstants.getStyleForMode(mode);
  }

  CameraPosition _cameraForMode(MapViewMode mode, {LatLng? target}) {
    final t = target ?? _campusCenter;
    switch (mode) {
      case MapViewMode.satellite:
        return CameraPosition(target: t, zoom: 17.0, tilt: 30, bearing: 0);
      case MapViewMode.buildings3D:
        return CameraPosition(target: t, zoom: 17.5, tilt: 55, bearing: 30);
      case MapViewMode.groundLevel:
        return CameraPosition(target: t, zoom: 18.5, tilt: 80, bearing: 0);
    }
  }

  // ──────────────────────────────────────────────────────────
  //  Lifecycle
  // ──────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _currentMode = widget.viewMode;
    // Start a timeout timer — if the map hasn't loaded in 15 s, show fallback
    _loadTimer = Timer(const Duration(seconds: 15), () {
      if (!_mapReady && mounted && !_isDisposed) {
        setState(() => _loadTimedOut = true);
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _mapReady = false;
    _loadTimer?.cancel();
    _mapController = null;
    super.dispose();
  }

  @override
  void didUpdateWidget(CampusMap3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isDisposed || !mounted) return;

    if (_mapReady) {
      // Handle view-mode change FIRST — it triggers setStyle which
      // invalidates the current style. _onStyleLoaded will re-add
      // all layers/markers, so skip the rest.
      if (widget.viewMode != oldWidget.viewMode) {
        switchViewMode(widget.viewMode);
        return;
      }
      if (widget.faculty != oldWidget.faculty ||
          widget.selectedFaculty != oldWidget.selectedFaculty) {
        _updateFacultyMarkers();
      }
      if (widget.userLocation != oldWidget.userLocation) {
        _updateUserLocationMarker();
      }
      if (widget.selectedFaculty != oldWidget.selectedFaculty &&
          widget.selectedFaculty != null) {
        _centerOnFaculty(widget.selectedFaculty!);
      }
    }
  }

  // ──────────────────────────────────────────────────────────
  //  Map lifecycle callbacks
  // ──────────────────────────────────────────────────────────

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
  }

  /// Handle map taps — check if a faculty circle layer feature was clicked.
  Future<void> _handleMapTap(math.Point<double> point, LatLng coords) async {
    if (widget.onMarkerTap == null || widget.faculty == null) {
      widget.onMapTap?.call(coords);
      return;
    }
    try {
      // Query rendered features at the tap point on our faculty layers
      final features = await _mapController?.queryRenderedFeatures(point, [
        _facultyCircleLayerId,
        _selectedCircleLayerId,
      ], null);
      if (features != null && features.isNotEmpty) {
        final fId = features.first['properties']?['id'] as String?;
        if (fId != null) {
          final faculty = widget.faculty!
              .where((f) => f.user.id == fId)
              .firstOrNull;
          if (faculty != null) {
            widget.onMarkerTap!(faculty);
            return;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CampusMap3D] queryRenderedFeatures error: $e');
      }
    }
    // No faculty hit — forward as generic map tap
    widget.onMapTap?.call(coords);
  }

  Future<void> _onStyleLoaded() async {
    if (_isDisposed) return;

    // Bump generation — any earlier _onStyleLoaded still running becomes stale
    final gen = ++_styleLoadGeneration;

    _loadTimer?.cancel();
    _buildingsAdded = false;
    _routeAdded = false;

    // Clear the timeout overlay, but keep _mapReady FALSE until data
    // is pushed to the GeoJSON sources.
    setState(() {
      _loadTimedOut = false;
    });

    if (kDebugMode) {
      debugPrint(
        '[CampusMap3D] Style loaded (gen=$gen). '
        'faculty=${widget.faculty?.length ?? 0}, '
        'sources+layers=runtime-added',
      );
    }

    // Add campus boundaries at runtime
    if (widget.showCampusBoundary) {
      try {
        await _addCampusBoundariesRuntime();
      } catch (e) {
        if (kDebugMode) debugPrint('Error adding campus boundaries: $e');
      }
      if (_isDisposed || !mounted || gen != _styleLoadGeneration) return;
    }

    // Add marker sources + layers at runtime
    try {
      await _addMarkerSourcesAndLayers();
    } catch (e) {
      if (kDebugMode) debugPrint('Error adding marker layers: $e');
    }
    if (_isDisposed || !mounted || gen != _styleLoadGeneration) return;

    // 3D buildings are added at runtime because they are large/complex
    // and only needed for specific view modes.
    if (widget.enable3DBuildings &&
        (_currentMode == MapViewMode.buildings3D ||
            _currentMode == MapViewMode.groundLevel)) {
      try {
        await _add3DCampusBuildings();
      } catch (e) {
        if (kDebugMode) debugPrint('Error adding 3D buildings: $e');
      }
      if (_isDisposed || !mounted || gen != _styleLoadGeneration) return;
    }

    // Push current data into the GeoJSON sources
    try {
      await _updateFacultyMarkers();
    } catch (e) {
      if (kDebugMode) debugPrint('Error updating faculty markers: $e');
    }
    if (_isDisposed || !mounted || gen != _styleLoadGeneration) return;
    try {
      await _updateUserLocationMarker();
    } catch (e) {
      if (kDebugMode) debugPrint('Error updating user location: $e');
    }
    if (_isDisposed || !mounted || gen != _styleLoadGeneration) return;

    // All layers are now populated — allow didUpdateWidget to update them.
    setState(() {
      _mapReady = true;
    });

    // Set camera for current mode
    try {
      final target = widget.selectedFaculty?.location != null
          ? LatLng(
              widget.selectedFaculty!.location!.latitude,
              widget.selectedFaculty!.location!.longitude,
            )
          : null;
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          _cameraForMode(_currentMode, target: target),
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Error setting camera: $e');
    }
  }

  // ──────────────────────────────────────────────────────────
  //  Campus boundary + 3D building layers
  // ──────────────────────────────────────────────────────────

  Future<void> _addCampusBoundariesRuntime() async {
    if (_mapController == null || _isDisposed) return;
    final gen = _styleLoadGeneration; // capture current generation
    for (final campus in AppConstants.campusesData) {
      // Abort if a newer style load has started
      if (_isDisposed || !mounted || gen != _styleLoadGeneration) return;

      final campusId = campus['id'] as String;
      final boundary = campus['boundaryPoints'] as List;
      final color = MapConstants.campusBoundaryColors[campusId] ?? '#41B3A3';

      final coordinates = boundary
          .map<List<double>>((p) => [(p as List)[1] as double, p[0] as double])
          .toList();
      if (coordinates.isNotEmpty) {
        coordinates.add(List<double>.from(coordinates.first));
      }

      final geoJson = {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Polygon',
              'coordinates': [coordinates],
            },
            'properties': {'color': color},
          },
        ],
      };

      final sourceId = 'campus-boundary-$campusId';
      try {
        await _mapController!.addGeoJsonSource(sourceId, geoJson);
        await _mapController!.addFillLayer(
          sourceId,
          'campus-fill-$campusId',
          FillLayerProperties(fillColor: color, fillOpacity: 0.15),
        );
        await _mapController!.addLineLayer(
          sourceId,
          'campus-line-$campusId',
          LineLayerProperties(
            lineColor: color,
            lineWidth: 3.0,
            lineOpacity: 0.9,
          ),
        );
      } catch (e) {
        if (kDebugMode) debugPrint('Error adding boundary for $campusId: $e');
      }
    }
  }

  Future<void> _add3DCampusBuildings() async {
    if (_mapController == null || _isDisposed || _buildingsAdded) return;

    final ctrl = _mapController!;
    final gen = _styleLoadGeneration; // capture current generation
    bool stale() => _isDisposed || !mounted || gen != _styleLoadGeneration;

    // For MapTiler styles, add PBF-based 3D buildings if available
    if (MapConstants.hasMapTilerKey) {
      try {
        await ctrl.addLayer(
          'openmaptiles',
          'osm-buildings-3d',
          const FillExtrusionLayerProperties(
            fillExtrusionColor: '#d4c4a8',
            fillExtrusionHeight: [
              'interpolate',
              ['linear'],
              ['zoom'],
              15,
              0,
              16,
              ['get', 'render_height'],
            ],
            fillExtrusionBase: [
              'interpolate',
              ['linear'],
              ['zoom'],
              15,
              0,
              16,
              ['get', 'render_min_height'],
            ],
            fillExtrusionOpacity: 0.6,
          ),
          sourceLayer: 'building',
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('OSM vector buildings not available in this style: $e');
        }
      }
    }

    // Add custom SKSU campus buildings — each step wrapped individually
    // so a duplicate-source error doesn't cascade to later steps.
    try {
      await ctrl.addGeoJsonSource(
        'sksu-campus-buildings',
        MapConstants.campusBuildingsGeoJson,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Source sksu-campus-buildings: $e');
    }
    if (stale()) return;

    final isGround = _currentMode == MapViewMode.groundLevel;
    try {
      await ctrl.addLayer(
        'sksu-campus-buildings',
        'sksu-buildings-3d',
        FillExtrusionLayerProperties(
          fillExtrusionColor: [Expressions.get, 'color'],
          fillExtrusionHeight: [Expressions.get, 'height'],
          fillExtrusionBase: [Expressions.get, 'base_height'],
          fillExtrusionOpacity: isGround ? 0.95 : 0.88,
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Layer sksu-buildings-3d: $e');
    }
    if (stale()) return;

    try {
      await ctrl.addLineLayer(
        'sksu-campus-buildings',
        'sksu-buildings-outline',
        const LineLayerProperties(
          lineColor: '#666666',
          lineWidth: 1.0,
          lineOpacity: 0.4,
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Layer sksu-buildings-outline: $e');
    }
    if (stale()) return;

    try {
      await ctrl.addSymbolLayer(
        'sksu-campus-buildings',
        'sksu-buildings-labels',
        const SymbolLayerProperties(
          textField: [Expressions.get, 'name'],
          textSize: 11,
          textColor: '#FFFFFF',
          textHaloColor: '#000000',
          textHaloWidth: 1.2,
          textAllowOverlap: false,
          textAnchor: 'center',
          textFont: ['Open Sans Regular'],
        ),
        minzoom: 17,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Layer sksu-buildings-labels: $e');
    }

    _buildingsAdded = true;
  }

  // ──────────────────────────────────────────────────────────
  //  Faculty & user markers  (GeoJSON sources + circle layers)
  //
  //  Using setGeoJsonSource / addLayer instead of addCircle()
  //  because the annotation API's JS interop hangs on Flutter web.
  //  GeoJSON layers are rendered natively by MapLibre's WebGL engine.
  // ──────────────────────────────────────────────────────────

  /// Add all marker GeoJSON sources + circle layers + route layer at runtime.
  /// Called from _onStyleLoaded after campus boundaries are set up.
  Future<void> _addMarkerSourcesAndLayers() async {
    if (_mapController == null || _isDisposed) return;
    final ctrl = _mapController!;
    final gen = _styleLoadGeneration;
    bool stale() => _isDisposed || !mounted || gen != _styleLoadGeneration;

    final emptyFc = {'type': 'FeatureCollection', 'features': <dynamic>[]};

    // ── Sources ──
    try {
      await ctrl.addGeoJsonSource(_facultySourceId, emptyFc);
    } catch (e) {
      if (kDebugMode) debugPrint('Source $_facultySourceId: $e');
    }
    if (stale()) return;
    try {
      await ctrl.addGeoJsonSource(_selectedSourceId, emptyFc);
    } catch (e) {
      if (kDebugMode) debugPrint('Source $_selectedSourceId: $e');
    }
    if (stale()) return;
    try {
      await ctrl.addGeoJsonSource(_userLocSourceId, emptyFc);
    } catch (e) {
      if (kDebugMode) debugPrint('Source $_userLocSourceId: $e');
    }
    if (stale()) return;
    try {
      await ctrl.addGeoJsonSource(_routeSourceId, emptyFc);
    } catch (e) {
      if (kDebugMode) debugPrint('Source $_routeSourceId: $e');
    }
    if (stale()) return;

    // ── Circle layers (order = bottom to top) ──

    // Faculty markers — white stroke behind colored fill
    try {
      await ctrl.addCircleLayer(
        _facultySourceId,
        _facultyStrokeLayerId,
        const CircleLayerProperties(
          circleRadius: 14,
          circleColor: '#FFFFFF',
          circleOpacity: 1.0,
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Layer $_facultyStrokeLayerId: $e');
    }
    if (stale()) return;
    try {
      await ctrl.addCircleLayer(
        _facultySourceId,
        _facultyCircleLayerId,
        const CircleLayerProperties(
          circleRadius: 12,
          circleColor: [Expressions.get, 'color'],
          circleOpacity: 1.0,
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Layer $_facultyCircleLayerId: $e');
    }
    if (stale()) return;

    // Selected faculty — larger, gold stroke
    try {
      await ctrl.addCircleLayer(
        _selectedSourceId,
        _selectedStrokeLayerId,
        const CircleLayerProperties(
          circleRadius: 20,
          circleColor: '#FFD700',
          circleOpacity: 1.0,
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Layer $_selectedStrokeLayerId: $e');
    }
    if (stale()) return;
    try {
      await ctrl.addCircleLayer(
        _selectedSourceId,
        _selectedCircleLayerId,
        const CircleLayerProperties(
          circleRadius: 16,
          circleColor: [Expressions.get, 'color'],
          circleOpacity: 1.0,
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Layer $_selectedCircleLayerId: $e');
    }
    if (stale()) return;

    // User location — blue glow + solid dot
    try {
      await ctrl.addCircleLayer(
        _userLocSourceId,
        _userLocGlowLayerId,
        const CircleLayerProperties(
          circleRadius: 20,
          circleColor: '#2196F3',
          circleOpacity: 0.18,
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Layer $_userLocGlowLayerId: $e');
    }
    if (stale()) return;
    try {
      await ctrl.addCircleLayer(
        _userLocSourceId,
        _userLocDotLayerId,
        const CircleLayerProperties(
          circleRadius: 10,
          circleColor: '#2196F3',
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 3.0,
          circleOpacity: 1.0,
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Layer $_userLocDotLayerId: $e');
    }
    if (stale()) return;

    // Route line
    try {
      await ctrl.addLineLayer(
        _routeSourceId,
        _routeLayerId,
        const LineLayerProperties(
          lineColor: '#4A90D9',
          lineWidth: 4.0,
          lineOpacity: 0.85,
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Layer $_routeLayerId: $e');
    }
  }

  /// Build a GeoJSON FeatureCollection from online faculty
  Map<String, dynamic> _buildFacultyGeoJson() {
    final features = <Map<String, dynamic>>[];
    if (widget.faculty != null) {
      for (final f in widget.faculty!) {
        // Trust the parent's filtering (e.g. admin _isVisible / student isOnline).
        // Only require a non-null, non-stale location for rendering.
        if (f.location == null || f.isLocationStale) continue;
        final isSelected = widget.selectedFaculty?.user.id == f.user.id;
        if (isSelected) continue; // selected drawn separately
        features.add({
          'type': 'Feature',
          'properties': {
            'id': f.user.id,
            'color': _getStatusColor(f.displayStatus),
          },
          'geometry': {
            'type': 'Point',
            'coordinates': [f.location!.longitude, f.location!.latitude],
          },
        });
      }
    }
    return {'type': 'FeatureCollection', 'features': features};
  }

  /// Build a GeoJSON FeatureCollection for the selected faculty
  Map<String, dynamic> _buildSelectedGeoJson() {
    final features = <Map<String, dynamic>>[];
    final sel = widget.selectedFaculty;
    if (sel != null && sel.location != null && !sel.isLocationStale) {
      features.add({
        'type': 'Feature',
        'properties': {
          'id': sel.user.id,
          'color': _getStatusColor(sel.displayStatus),
        },
        'geometry': {
          'type': 'Point',
          'coordinates': [sel.location!.longitude, sel.location!.latitude],
        },
      });
    }
    return {'type': 'FeatureCollection', 'features': features};
  }

  Future<void> _updateFacultyMarkers() async {
    if (_mapController == null || _isDisposed || !mounted) return;

    final geoJson = _buildFacultyGeoJson();
    final selectedGeoJson = _buildSelectedGeoJson();

    try {
      // Sources + layers are baked into the style JSON (see _buildStyle),
      // so we only need to push data — no addGeoJsonSource / addCircleLayer.
      await _mapController!.setGeoJsonSource(_facultySourceId, geoJson);
      await _mapController!.setGeoJsonSource(
        _selectedSourceId,
        selectedGeoJson,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CampusMap3D] Error updating faculty GeoJSON layers: $e');
      }
    }
  }

  /// Build a GeoJSON FeatureCollection for the user's own location
  Map<String, dynamic> _buildUserLocGeoJson() {
    final features = <Map<String, dynamic>>[];
    if (widget.userLocation != null) {
      features.add({
        'type': 'Feature',
        'properties': {},
        'geometry': {
          'type': 'Point',
          'coordinates': [
            widget.userLocation!.longitude,
            widget.userLocation!.latitude,
          ],
        },
      });
    }
    return {'type': 'FeatureCollection', 'features': features};
  }

  Future<void> _updateUserLocationMarker() async {
    if (_mapController == null || _isDisposed || !mounted) return;

    final geoJson = _buildUserLocGeoJson();

    try {
      // Source + layers are baked into the style JSON (see _buildStyle).
      await _mapController!.setGeoJsonSource(_userLocSourceId, geoJson);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CampusMap3D] Error updating user location layer: $e');
      }
    }
  }

  String _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available for consultation':
      case 'available':
      case 'online':
        return '#41B3A3';
      case 'in a class':
      case 'teaching':
        return '#6EB5A0';
      case 'in a meeting':
      case 'in meeting':
      case 'meeting':
        return '#C38D9E';
      case 'on break':
      case 'break time':
        return '#D4A373';
      case 'out of office':
      case 'away':
      case 'office hours':
        return '#8D8D8D';
      case 'busy':
      case 'do not disturb':
        return '#E8A87C';
      default:
        return '#8D8D8D';
    }
  }

  // ──────────────────────────────────────────────────────────
  //  Public controls (callable from parent widgets)
  // ──────────────────────────────────────────────────────────

  /// Switch view mode at runtime (updates style + camera)
  void switchViewMode(MapViewMode mode) {
    if (_isDisposed || !mounted || _mapController == null) return;
    _currentMode = mode;
    _buildingsAdded = false;
    // Mark map as NOT ready — prevents didUpdateWidget from triggering
    // marker updates while the old style is being torn down.
    _mapReady = false;

    final newStyle = _buildStyle(mode);
    try {
      _mapController!.setStyle(newStyle);
      // onStyleLoaded will fire again, set _mapReady = true,
      // and re-add buildings + markers.
    } catch (e) {
      if (kDebugMode) debugPrint('Error switching style: $e');
    }
  }

  /// Fly to a campus with a dramatic zoom-out-then-zoom-in animation.
  /// If [campusId] is provided, it overrides the widget's campusId.
  void centerOnCampus({String? campusId}) {
    if (_isDisposed || !mounted || _mapController == null) return;

    LatLng target = _campusCenter;
    if (campusId != null) {
      final center = AppConstants.getCampusCenter(campusId);
      if (center != null) target = LatLng(center[0], center[1]);
    }

    // Calculate distance from current camera to target to decide animation
    final currentTarget = _mapController!.cameraPosition?.target;
    double distKm = 0;
    if (currentTarget != null) {
      distKm = _haversineKm(
        currentTarget.latitude,
        currentTarget.longitude,
        target.latitude,
        target.longitude,
      );
    }

    final cam = _cameraForMode(_currentMode, target: target);

    if (distKm < 0.5) {
      // Same campus / very close — simple short animation
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(cam),
        duration: const Duration(milliseconds: 800),
      );
    } else {
      // Different campus — two-phase: zoom out then fly to target
      // Phase 1: zoom out to show both campuses
      final midLat = (currentTarget!.latitude + target.latitude) / 2;
      final midLng = (currentTarget.longitude + target.longitude) / 2;
      final zoomOut = distKm > 50 ? 8.0 : (distKm > 10 ? 10.0 : 12.0);

      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(midLat, midLng),
            zoom: zoomOut,
            tilt: 0,
            bearing: 0,
          ),
        ),
        duration: const Duration(milliseconds: 1200),
      );

      // Phase 2: fly into the target campus after phase 1 finishes
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (_isDisposed || !mounted || _mapController == null) return;
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(cam),
          duration: const Duration(milliseconds: 1500),
        );
      });
    }
  }

  /// Haversine distance in km between two lat/lng points
  static double _haversineKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371.0; // Earth radius km
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _deg2rad(double deg) => deg * (math.pi / 180);

  void centerOnUser() {
    if (_isDisposed || !mounted || _mapController == null) return;
    if (widget.userLocation != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          _cameraForMode(_currentMode, target: widget.userLocation),
        ),
      );
    }
  }

  void centerOnFaculty(FacultyWithLocation faculty) =>
      _centerOnFaculty(faculty);

  void _centerOnFaculty(FacultyWithLocation faculty) {
    if (faculty.location == null ||
        _mapController == null ||
        _isDisposed ||
        !mounted) {
      return;
    }
    final loc = LatLng(faculty.location!.latitude, faculty.location!.longitude);
    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(_cameraForMode(_currentMode, target: loc)),
    );
  }

  void rotate3D() {
    if (_isDisposed || !mounted || _mapController == null) return;
    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _campusCenter,
          zoom: 17.5,
          tilt: 60,
          bearing: 45,
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  //  Route line (user → faculty direction)
  // ──────────────────────────────────────────────────────────

  static const _routeSourceId = 'route-line-source';
  static const _routeLayerId = 'route-line-layer';

  /// Draw a straight direction line between two points and zoom to fit both.
  Future<void> showRoute(LatLng from, LatLng to) async {
    if (_isDisposed || !mounted || _mapController == null || !_mapReady) return;

    final geoJson = {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              [from.longitude, from.latitude],
              [to.longitude, to.latitude],
            ],
          },
          'properties': <String, dynamic>{},
        },
      ],
    };

    try {
      // Source + layer are baked into the style JSON — just push data.
      await _mapController!.setGeoJsonSource(_routeSourceId, geoJson);
      _routeAdded = true;

      // Zoom to fit both points with padding
      final southwest = LatLng(
        math.min(from.latitude, to.latitude),
        math.min(from.longitude, to.longitude),
      );
      final northeast = LatLng(
        math.max(from.latitude, to.latitude),
        math.max(from.longitude, to.longitude),
      );
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(southwest: southwest, northeast: northeast),
          left: 60,
          top: 100,
          right: 60,
          bottom: 200,
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Error showing route: $e');
    }
  }

  /// Remove the direction line from the map.
  Future<void> clearRoute() async {
    if (_isDisposed || !mounted || _mapController == null || !_routeAdded) {
      return;
    }
    try {
      // Clear the route by setting an empty FeatureCollection
      await _mapController!.setGeoJsonSource(_routeSourceId, {
        'type': 'FeatureCollection',
        'features': <dynamic>[],
      });
    } catch (_) {}
    _routeAdded = false;
  }

  // ──────────────────────────────────────────────────────────
  //  Build
  // ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final initialCamera = widget.selectedFaculty?.location != null
        ? _cameraForMode(
            _currentMode,
            target: LatLng(
              widget.selectedFaculty!.location!.latitude,
              widget.selectedFaculty!.location!.longitude,
            ),
          )
        : _cameraForMode(_currentMode);

    return Stack(
      children: [
        // MapLibre GL Map
        RepaintBoundary(
          child: MapLibreMap(
            onMapCreated: _onMapCreated,
            onStyleLoadedCallback: _onStyleLoaded,
            onMapClick: (point, coordinates) {
              // Check if a faculty marker was tapped
              _handleMapTap(point, coordinates);
            },
            initialCameraPosition: initialCamera,
            styleString: _buildStyle(_currentMode),
            myLocationEnabled: false,
            trackCameraPosition: false,
            compassEnabled: true,
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: true,
            // Clamp zoom to tile source limits to stop tile-fetch errors
            minMaxZoomPreference: const MinMaxZoomPreference(5, 19),
          ),
        ),

        // Loading overlay
        if (!_mapReady)
          Container(
            color: AppColors.background.withValues(alpha: 0.85),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_loadTimedOut) ...[
                    const CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: 16),
                    Text(
                      _loadingLabel,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ] else ...[
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 48,
                      color: AppColors.warning,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '3D map is taking too long to load',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Try switching to Satellite view',
                      style: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  // Badge helpers
  String get _loadingLabel {
    switch (_currentMode) {
      case MapViewMode.satellite:
        return 'Loading Satellite View...';
      case MapViewMode.buildings3D:
        return 'Loading 3D Campus...';
      case MapViewMode.groundLevel:
        return 'Loading Ground View...';
    }
  }
}
