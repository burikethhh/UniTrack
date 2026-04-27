import 'dart:convert';
import 'dart:math';


/// Map configuration constants for UniTrack
///
/// To enable premium map features (vector streets, satellite labels,
/// full 3D building data from OpenStreetMap), sign up for a free
/// MapTiler API key at: https://cloud.maptiler.com/account/keys/
///
/// Free tier: 100,000 tile loads/month — sufficient for a university app.
class MapConstants {
  MapConstants._();

  // ============================================================
  // MapTiler API Key
  // ============================================================
  /// Replace with your own key from https://cloud.maptiler.com/account/keys/
  static const String mapTilerApiKey = 'YOUR_MAPTILER_API_KEY';

  /// Whether a valid MapTiler API key is configured
  static bool get hasMapTilerKey =>
      mapTilerApiKey.isNotEmpty && mapTilerApiKey != 'YOUR_MAPTILER_API_KEY';

  // ============================================================
  // MapTiler Style URLs (requires valid API key)
  // ============================================================
  static String get mapTilerStreetsStyle =>
      'https://api.maptiler.com/maps/streets-v2/style.json?key=$mapTilerApiKey';
  static String get mapTilerSatelliteStyle =>
      'https://api.maptiler.com/maps/hybrid/style.json?key=$mapTilerApiKey';
  static String get mapTilerOutdoorStyle =>
      'https://api.maptiler.com/maps/outdoor-v2/style.json?key=$mapTilerApiKey';

  // MapTiler raster tiles for flutter_map (2D fallback)
  static String get mapTilerRasterUrl =>
      'https://api.maptiler.com/maps/streets-v2/256/{z}/{x}/{y}.png?key=$mapTilerApiKey';
  static String get mapTilerSatelliteRasterUrl =>
      'https://api.maptiler.com/maps/hybrid/256/{z}/{x}/{y}.png?key=$mapTilerApiKey';

  // ============================================================
  // Free Fallback Tile Sources (no API key required)
  // ============================================================
  static const String osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String osmAttribution = '© OpenStreetMap contributors';

  // ESRI World Imagery satellite tiles (free for typical usage)
  static const String esriSatelliteUrl =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
  static const String esriHybridUrl =
      'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Transportation/MapServer/tile/{z}/{y}/{x}';
  static const String esriAttribution = '© Esri, Maxar, Earthstar Geographics';

  // ============================================================
  // External Street View URLs
  // ============================================================

  /// Google Maps Street View at a given location
  static String googleStreetViewUrl(double lat, double lng) =>
      'https://www.google.com/maps/@$lat,$lng,3a,75y,0h,90t/data=!3m4!1e1!3m2!1s!2e0';

  /// Mapillary street-level imagery at a given location
  static String mapillaryUrl(double lat, double lng) =>
      'https://www.mapillary.com/app/?lat=$lat&lng=$lng&z=17';

  /// Google Maps walking directions to a destination
  static String googleDirectionsUrl(double destLat, double destLng) =>
      'https://www.google.com/maps/dir/?api=1&destination=$destLat,$destLng&travelmode=walking';

  // ============================================================
  // Campus boundary colors (unified across all map widgets)
  // ============================================================
  static const Map<String, String> campusBoundaryColors = {
    'isulan': '#41B3A3',
    'tacurong': '#FF9800',
    'access': '#9C27B0',
    'bagumbayan': '#009688',
    'palimbang': '#3F51B5',
    'kalamansig': '#E91E63',
    'lutayan': '#795548',
  };

  // ============================================================
  // Campus Building Data for 3D Extrusions
  // ============================================================

  /// Generate a building rectangle polygon from center and metric dimensions.
  static Map<String, dynamic> _building(
    String name,
    double lat,
    double lng,
    double widthM,
    double lengthM,
    double height,
    String color, {
    double baseHeight = 0,
    String? campus,
  }) {
    final latDeg = lengthM / 2 / 111000;
    final lngDeg = widthM / 2 / (111000 * cos(lat * pi / 180));
    return {
      'type': 'Feature',
      'properties': {
        'name': name,
        'height': height,
        'base_height': baseHeight,
        'color': color,
        'campus': ?campus,
      },
      'geometry': {
        'type': 'Polygon',
        'coordinates': [
          [
            [lng - lngDeg, lat - latDeg],
            [lng + lngDeg, lat - latDeg],
            [lng + lngDeg, lat + latDeg],
            [lng - lngDeg, lat + latDeg],
            [lng - lngDeg, lat - latDeg],
          ],
        ],
      },
    };
  }

  /// GeoJSON FeatureCollection of all SKSU campus buildings
  static Map<String, dynamic> get campusBuildingsGeoJson => {
    'type': 'FeatureCollection',
    'features': [
      // ═══════════ ISULAN CAMPUS (Main) ═══════════
      _building(
        'Administration Building',
        6.63355,
        124.60880,
        35,
        20,
        14,
        '#C8A882',
        campus: 'isulan',
      ),
      _building(
        'Main Academic Building',
        6.63310,
        124.60930,
        50,
        18,
        14,
        '#D4B896',
        campus: 'isulan',
      ),
      _building(
        'College of Education',
        6.63345,
        124.60955,
        40,
        15,
        10,
        '#CCAD8A',
        campus: 'isulan',
      ),
      _building(
        'Science Building',
        6.63290,
        124.60875,
        35,
        18,
        14,
        '#C8A882',
        campus: 'isulan',
      ),
      _building(
        'University Library',
        6.63365,
        124.60925,
        30,
        20,
        10,
        '#E0C8A8',
        campus: 'isulan',
      ),
      _building(
        'Gymnasium',
        6.63275,
        124.60945,
        40,
        30,
        12,
        '#B8A080',
        campus: 'isulan',
      ),
      _building(
        'Student Center',
        6.63335,
        124.60860,
        25,
        15,
        7,
        '#D8C0A0',
        campus: 'isulan',
      ),
      _building(
        'Engineering Building',
        6.63300,
        124.60960,
        35,
        15,
        10,
        '#C0A878',
        campus: 'isulan',
      ),

      // ═══════════ TACURONG CAMPUS ═══════════
      _building(
        'Main Building',
        6.69190,
        124.67820,
        45,
        18,
        14,
        '#A8C8B8',
        campus: 'tacurong',
      ),
      _building(
        'Admin Building',
        6.69160,
        124.67850,
        30,
        15,
        10,
        '#B0D0C0',
        campus: 'tacurong',
      ),
      _building(
        'Training Hall',
        6.69175,
        124.67790,
        35,
        25,
        11,
        '#98B8A8',
        campus: 'tacurong',
      ),
      _building(
        'College of Business',
        6.69200,
        124.67855,
        35,
        15,
        10,
        '#A0C0B0',
        campus: 'tacurong',
      ),

      // ═══════════ ACCESS CAMPUS ═══════════
      _building(
        'ACCESS Main Building',
        6.66890,
        124.62955,
        40,
        18,
        11,
        '#B8B8D0',
        campus: 'access',
      ),
      _building(
        'Multi-purpose Hall',
        6.66860,
        124.62990,
        30,
        22,
        9,
        '#A8A8C0',
        campus: 'access',
      ),
      _building(
        'Workshop Building',
        6.66880,
        124.62930,
        25,
        15,
        8,
        '#C0C0D8',
        campus: 'access',
      ),

      // ═══════════ BAGUMBAYAN CAMPUS ═══════════
      _building(
        'Main Academic Hall',
        6.53210,
        124.55070,
        40,
        18,
        11,
        '#C8D0A8',
        campus: 'bagumbayan',
      ),
      _building(
        'Administration',
        6.53195,
        124.55090,
        25,
        15,
        9,
        '#D0D8B0',
        campus: 'bagumbayan',
      ),

      // ═══════════ PALIMBANG CAMPUS ═══════════
      _building(
        'Main Campus Building',
        6.22100,
        124.19225,
        40,
        18,
        11,
        '#D0C0A8',
        campus: 'palimbang',
      ),
      _building(
        'Faculty Office',
        6.22085,
        124.19245,
        20,
        12,
        8,
        '#D8C8B0',
        campus: 'palimbang',
      ),

      // ═══════════ KALAMANSIG CAMPUS ═══════════
      _building(
        'Main Building',
        6.55775,
        124.04795,
        40,
        18,
        11,
        '#C0D0D0',
        campus: 'kalamansig',
      ),
      _building(
        'Annex Building',
        6.55755,
        124.04810,
        25,
        12,
        8,
        '#C8D8D8',
        campus: 'kalamansig',
      ),

      // ═══════════ LUTAYAN CAMPUS ═══════════
      _building(
        'Main Campus Hall',
        6.57325,
        124.87640,
        40,
        18,
        11,
        '#D0C8D0',
        campus: 'lutayan',
      ),
      _building(
        'Resource Center',
        6.57310,
        124.87660,
        20,
        15,
        8,
        '#D8D0D8',
        campus: 'lutayan',
      ),
    ],
  };

  // ============================================================
  // MapLibre Style Builders (fallback styles — no API key needed)
  // ============================================================

  /// Build a satellite style using free ESRI imagery
  static String buildSatelliteStyle() {
    final style = {
      'version': 8,
      'name': 'UniTrack Satellite',
      'glyphs': 'https://demotiles.maplibre.org/font/{fontstack}/{range}.pbf',
      'sources': {
        'satellite': {
          'type': 'raster',
          'tiles': [esriSatelliteUrl],
          'tileSize': 256,
          'maxzoom': 18,
          'attribution': esriAttribution,
        },
        'labels': {
          'type': 'raster',
          'tiles': [esriHybridUrl],
          'tileSize': 256,
          'maxzoom': 18,
        },
      },
      'layers': [
        {'id': 'satellite-tiles', 'type': 'raster', 'source': 'satellite'},
        {
          'id': 'label-tiles',
          'type': 'raster',
          'source': 'labels',
          'paint': {'raster-opacity': 0.7},
        },
      ],
    };
    return jsonEncode(style);
  }

  /// Build a 3D campus style with building extrusions on satellite base
  static String build3DCampusStyle() {
    // Base style: satellite + labels only.
    // 3D campus buildings are added at runtime via addGeoJsonSource()
    // to avoid MapLibre worker parse errors with large inline GeoJSON.
    final style = {
      'version': 8,
      'name': 'UniTrack 3D Campus',
      'glyphs': 'https://demotiles.maplibre.org/font/{fontstack}/{range}.pbf',
      'sources': {
        'satellite': {
          'type': 'raster',
          'tiles': [esriSatelliteUrl],
          'tileSize': 256,
          'maxzoom': 18,
          'attribution': esriAttribution,
        },
        'labels': {
          'type': 'raster',
          'tiles': [esriHybridUrl],
          'tileSize': 256,
          'maxzoom': 18,
        },
      },
      'layers': [
        {'id': 'satellite-tiles', 'type': 'raster', 'source': 'satellite'},
        {
          'id': 'label-tiles',
          'type': 'raster',
          'source': 'labels',
          'paint': {'raster-opacity': 0.6},
        },
      ],
    };
    return jsonEncode(style);
  }

  /// Build a ground-level style using satellite imagery.
  ///
  /// At 80° tilt with extreme zoom, satellite imagery gives a realistic
  /// feel. Labels are overlaid at reduced opacity for context.
  static String buildGroundLevelStyle() {
    final style = {
      'version': 8,
      'name': 'UniTrack Ground Level',
      'glyphs': 'https://demotiles.maplibre.org/font/{fontstack}/{range}.pbf',
      'sources': {
        'satellite': {
          'type': 'raster',
          'tiles': [esriSatelliteUrl],
          'tileSize': 256,
          'maxzoom': 18,
          'attribution': esriAttribution,
        },
        'labels': {
          'type': 'raster',
          'tiles': [esriHybridUrl],
          'tileSize': 256,
          'maxzoom': 18,
        },
      },
      'layers': [
        {'id': 'satellite-tiles', 'type': 'raster', 'source': 'satellite'},
        {
          'id': 'label-tiles',
          'type': 'raster',
          'source': 'labels',
          'paint': {'raster-opacity': 0.5},
        },
      ],
    };
    return jsonEncode(style);
  }

  /// Get the right style for a given [MapViewMode].
  /// When MapTiler key is available, uses premium vector styles;
  /// otherwise falls back to free raster alternatives.
  static String getStyleForMode(MapViewMode mode) {
    switch (mode) {
      case MapViewMode.satellite:
        return hasMapTilerKey ? mapTilerSatelliteStyle : buildSatelliteStyle();
      case MapViewMode.buildings3D:
        return hasMapTilerKey ? mapTilerSatelliteStyle : build3DCampusStyle();
      case MapViewMode.groundLevel:
        return hasMapTilerKey
            ? mapTilerSatelliteStyle
            : buildGroundLevelStyle();
    }
  }

  // NOTE: Campus boundaries and 3D buildings are added exclusively at
  // runtime via addGeoJsonSource() to avoid MapLibre web-worker parse errors.
}

/// Available map view modes
enum MapViewMode {
  satellite, // Satellite imagery (ESRI or MapTiler)
  buildings3D, // 3D buildings with tilt on satellite base
  groundLevel, // Street-level perspective (extreme camera tilt, satellite base)
}
