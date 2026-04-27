import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/map_constants.dart';
import '../../providers/providers.dart';
import '../../widgets/map/campus_map.dart';
import '../../widgets/map/campus_map_3d.dart';
import '../../widgets/map/campus_selector.dart';
import '../../widgets/map/map_view_controls.dart';

/// Staff map screen with GPS auto-tracking and multi-mode views
/// (satellite, 3D buildings, ground level).
class StaffMapScreen extends StatefulWidget {
  final bool use3D;

  const StaffMapScreen({super.key, this.use3D = false});

  @override
  State<StaffMapScreen> createState() => _StaffMapScreenState();
}

class _StaffMapScreenState extends State<StaffMapScreen> {
  final GlobalKey<CampusMap3DState> _map3dKey = GlobalKey<CampusMap3DState>();
  final GlobalKey<CampusMapState> _map2dKey = GlobalKey<CampusMapState>();
  LatLng? _currentGpsLocation;
  late bool _use3DMap;
  MapViewMode _mapMode = MapViewMode.satellite;
  String? _selectedCampusId;
  bool _showLegend = false;
  Timer? _locationRefreshTimer;

  @override
  void initState() {
    super.initState();
    _use3DMap = widget.use3D;
    _mapMode = widget.use3D ? MapViewMode.buildings3D : MapViewMode.satellite;
    _getCurrentLocation();

    // Refresh GPS every 30 seconds so the marker stays current
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
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      final locationProvider = context.read<LocationProvider>();
      final position = await locationProvider.getCurrentPosition();
      if (position != null && mounted) {
        setState(() {
          _currentGpsLocation = LatLng(position.latitude, position.longitude);
        });
      }
    } catch (e) {
      debugPrint('Staff location error: $e');
    }
  }

  @override
  void dispose() {
    _locationRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitle),
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
        ],
      ),
      body: Stack(
        children: [
          // Map
          _use3DMap ? _build3DMap() : _build2DMap(),

          // ── Top controls ──
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Row(
              children: [
                if (_use3DMap)
                  MapViewModeDropdown(
                    currentMode: _mapMode,
                    onModeChanged: (mode) => setState(() => _mapMode = mode),
                  ),
                const Spacer(),
                _buildCampusPill(),
              ],
            ),
          ),

          // ── Campus legend (bottom left) ──
          _buildCampusLegend(),
        ],
      ),
    );
  }

  String get _appBarTitle {
    if (!_use3DMap) return 'Campus Map';
    switch (_mapMode) {
      case MapViewMode.satellite:
        return 'Satellite View';
      case MapViewMode.buildings3D:
        return '3D Campus View';
      case MapViewMode.groundLevel:
        return 'Ground Level View';
    }
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
      if (_currentGpsLocation != null && mounted) {
        if (_use3DMap) {
          // 3D: handled by CampusMap3D
        } else {
          _map2dKey.currentState?.flyTo(_currentGpsLocation!, 18.0);
        }
      }
    });
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

  /// Build campus legend overlay with navigation
  Widget _buildCampusLegend() {
    return Positioned(
      left: 12,
      bottom: 16,
      child: CampusLegend(
        expanded: _showLegend,
        selectedCampusId: _selectedCampusId ?? AppConstants.defaultCampusId,
        onToggle: () => setState(() => _showLegend = !_showLegend),
        onCampusSelected: (campusId) {
          setState(() => _selectedCampusId = campusId);
          _animateToCampus(campusId);
        },
      ),
    );
  }

  /// Build 2D flutter_map — reliable on web (pure Dart, no JS interop)
  Widget _build2DMap() {
    return CampusMap(
      key: _map2dKey,
      userLocation: _currentGpsLocation,
      showCampusBoundary: true,
      campusId: _selectedCampusId ?? AppConstants.defaultCampusId,
    );
  }

  /// Build 3D MapLibre map (native platforms only)
  Widget _build3DMap() {
    return CampusMap3D(
      key: _map3dKey,
      userLocation: _currentGpsLocation != null
          ? maplibre.LatLng(
              _currentGpsLocation!.latitude,
              _currentGpsLocation!.longitude,
            )
          : null,
      showCampusBoundary: true,
      enable3DBuildings: true,
      campusId: _selectedCampusId ?? AppConstants.defaultCampusId,
      viewMode: _mapMode,
    );
  }
}
