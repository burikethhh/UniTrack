// App-wide constants for UniTrack

/// Constants class containing all static configuration values
class AppConstants {
  // App Info
  static const String appName = 'UniTrack';
  static const String appVersion = '2.0.6'; // Code cleanup and bug fixes
  static const int versionCode = 206; // Version code for update checks (2.0.6 = 206)
  static const String appTagline = 'Real-Time Faculty & Staff Locator';
  
  // Version Compatibility - for older app versions to update
  static const int apiVersion = 2; // Current API version
  static const int minSupportedApiVersion = 1; // Minimum API version we support
  static const int minSupportedVersionCode = 100; // Oldest version that can still use the app
  static const String updateCheckEndpoint = 'app_versions'; // Firestore collection for updates
  
  // GitHub Release URLs (for free hosting)
  static const String githubRepo = 'burikethhh/UniTrack';
  static const String githubReleasesUrl = 'https://github.com/burikethhh/UniTrack/releases';
  
  // University Info
  static const String universityName = 'Sultan Kudarat State University';
  static const String universityShortName = 'SKSU';
  
  // Default campus (for legacy support)
  static const String defaultCampusId = 'isulan';
  
  // ==================== MULTI-CAMPUS DATA ====================
  
  /// All SKSU Campuses
  static const List<Map<String, dynamic>> campusesData = [
    // ISULAN CAMPUS (Main) - Original coordinates
    {
      'id': 'isulan',
      'name': 'Isulan Campus',
      'shortName': 'Isulan',
      'location': 'Kalawag II, Isulan, Sultan Kudarat',
      'centerLat': 6.63326077657394,
      'centerLng': 124.6091426890741,
      'radiusMeters': 300.0,
      'boundaryPoints': [
        [6.634366440733132, 124.60838094171481], // Point 1 (NW)
        [6.6323575936484644, 124.60843458589574], // Point 2 (SW)
        [6.632330951059586, 124.61036041196797], // Point 3 (SE)
        [6.634419725690066, 124.61043014940196], // Point 4 (NE)
      ],
    },
    // TACURONG CAMPUS
    // Generated: 1/12/2026, 6:52:06 PM - 4 Points
    {
      'id': 'tacurong',
      'name': 'Tacurong Campus',
      'shortName': 'Tacurong',
      'location': 'Tacurong City, Sultan Kudarat',
      'centerLat': 6.691763,
      'centerLng': 124.67835,
      'radiusMeters': 300.0,
      'boundaryPoints': [
        [6.691965508743294, 124.67739539486075], // Point 1
        [6.690958676273667, 124.67775718829165], // Point 2
        [6.69156348754656, 124.6793154075242],   // Point 3
        [6.6925667610656205, 124.67891421084721], // Point 4
      ],
    },
    // ACCESS CAMPUS
    // Generated: 1/12/2026, 6:50:41 PM - 7 Points
    {
      'id': 'access',
      'name': 'ACCESS Campus',
      'shortName': 'ACCESS',
      'location': 'EJC Montilla, Tacurong City, Sultan Kudarat',
      'centerLat': 6.668761,
      'centerLng': 124.62971,
      'radiusMeters': 350.0,
      'boundaryPoints': [
        [6.668276950970167, 124.63226208568727], // Point 1
        [6.670700008931732, 124.63010993858899], // Point 2
        [6.669530258308484, 124.62879201137662], // Point 3
        [6.667984512129962, 124.62816809902563], // Point 4
        [6.666821717872736, 124.62913551368223], // Point 5
        [6.667699035950875, 124.63019406160328], // Point 6
        [6.667072380341509, 124.63090209696804], // Point 7
      ],
    },
    // BAGUMBAYAN CAMPUS
    // Generated: 2/6/2026, 9:53:04 PM - 4 Points
    {
      'id': 'bagumbayan',
      'name': 'Bagumbayan Campus',
      'shortName': 'Bagumbayan',
      'location': 'Bagumbayan, Sultan Kudarat',
      'centerLat': 6.532042,
      'centerLng': 124.55077,
      'radiusMeters': 300.0,
      'boundaryPoints': [
        [6.53071804227379, 124.5515311944688], // Point 1
        [6.533366494868773, 124.55161277609346], // Point 2
        [6.53335067712834, 124.54999497993191], // Point 3
        [6.530823262261578, 124.54992954735718], // Point 4
      ],
    },
    // PALIMBANG CAMPUS
    // Generated: 2/6/2026, 9:56:47 PM - 4 Points
    {
      'id': 'palimbang',
      'name': 'Palimbang Campus',
      'shortName': 'Palimbang',
      'location': 'Palimbang, Sultan Kudarat',
      'centerLat': 6.220947,
      'centerLng': 124.19232,
      'radiusMeters': 300.0,
      'boundaryPoints': [
        [6.221914907563686, 124.1933454945817], // Point 1
        [6.219998614113081, 124.19329161631686], // Point 2
        [6.219980760413989, 124.19125621519999], // Point 3
        [6.221903005141641, 124.19142383646755], // Point 4
      ],
    },
    // KALAMANSIG CAMPUS
    // Generated: 2/6/2026, 10:01:40 PM - 4 Points
    {
      'id': 'kalamansig',
      'name': 'Kalamansig Campus',
      'shortName': 'Kalamansig',
      'location': 'Kalamansig, Sultan Kudarat',
      'centerLat': 6.557669,
      'centerLng': 124.04801,
      'radiusMeters': 300.0,
      'boundaryPoints': [
        [6.557066532857306, 124.04901252402834], // Point 1
        [6.557272844078227, 124.04712093539888], // Point 2
        [6.558341532702741, 124.04701492861096], // Point 3
        [6.557997084028955, 124.04888382568726], // Point 4
      ],
    },
    // LUTAYAN CAMPUS
    // Generated: 2/6/2026, 10:08:49 PM - 4 Points
    {
      'id': 'lutayan',
      'name': 'Lutayan Campus',
      'shortName': 'Lutayan',
      'location': 'Lutayan, Sultan Kudarat',
      'centerLat': 6.573177,
      'centerLng': 124.87645,
      'radiusMeters': 350.0,
      'boundaryPoints': [
        [6.5708568198500785, 124.87550116160457], // Point 1
        [6.575638831950215, 124.87560522336327], // Point 2
        [6.575623514492463, 124.87734294059965], // Point 3
        [6.5707145257072455, 124.87739753507475], // Point 4
      ],
    },
  ];
  
  /// Get campus list for dropdown
  static List<Map<String, String>> get campusList => campusesData
      .map((c) => {
            'id': c['id'] as String,
            'name': c['name'] as String,
            'shortName': c['shortName'] as String,
          })
      .toList();
  
  /// Get campus by ID
  static Map<String, dynamic>? getCampusById(String id) {
    try {
      return campusesData.firstWhere((c) => c['id'] == id);
    } catch (_) {
      return null;
    }
  }
  
  /// Get campus center coordinates
  static List<double>? getCampusCenter(String campusId) {
    final campus = getCampusById(campusId);
    if (campus == null) return null;
    return [campus['centerLat'] as double, campus['centerLng'] as double];
  }
  
  /// Get campus boundary points
  static List<List<double>>? getCampusBoundary(String campusId) {
    final campus = getCampusById(campusId);
    if (campus == null) return null;
    return (campus['boundaryPoints'] as List).cast<List<double>>();
  }
  
  /// Check if coordinates are within a campus
  static bool isWithinCampus(String campusId, double lat, double lng) {
    final campus = getCampusById(campusId);
    if (campus == null) return false;
    
    final centerLat = campus['centerLat'] as double;
    final centerLng = campus['centerLng'] as double;
    final radius = campus['radiusMeters'] as double;
    
    // Simple distance calculation (Haversine approximation)
    final double dLat = (lat - centerLat) * 111320; // meters
    final double dLng = (lng - centerLng) * 111320 * 0.85; // adjusted for latitude
    final double distance = (dLat * dLat + dLng * dLng);
    return distance <= radius * radius;
  }
  
  // Legacy support: Default to Isulan campus (Original coordinates)
  static const String campusName = 'SKSU Isulan Campus';
  static const String campusLocation = 'Kalawag II, Isulan, Sultan Kudarat';
  static const double campusCenterLat = 6.63326077657394;
  static const double campusCenterLng = 124.6091426890741;
  static const double campusRadiusMeters = 300.0;
  static const List<List<double>> campusBoundaryPoints = [
    [6.634366440733132, 124.60838094171481], // Point 1 (NW)
    [6.6323575936484644, 124.60843458589574], // Point 2 (SW)
    [6.632330951059586, 124.61036041196797], // Point 3 (SE)
    [6.634419725690066, 124.61043014940196], // Point 4 (NE)
  ];
  
  // Firebase Collections
  static const String usersCollection = 'users';
  static const String locationsCollection = 'locations';
  static const String departmentsCollection = 'departments';
  static const String statusPresetsCollection = 'status_presets';
  
  // Location Update Settings
  static const int locationUpdateIntervalSeconds = 10;
  static const int locationAccuracyMeters = 10;
  
  // Status Options
  static const List<String> statusPresets = [
    'Available for Consultation',
    'In a Class',
    'In a Meeting',
    'Break Time',
    'Office Hours',
    'Do Not Disturb',
    'Away',
  ];
  
  // Quick Messages
  static const List<String> quickMessages = [
    'Back in 10 minutes',
    'Back in 30 minutes',
    'See me tomorrow',
    'Currently busy, email me',
    'In another building',
    'Please wait',
  ];
  
  // User Roles
  static const String roleStudent = 'student';
  static const String roleStaff = 'staff';
  static const String roleAdmin = 'admin';
  
  // Location staleness threshold (seconds) - location older than this is considered stale
  static const int locationStaleThresholdSeconds = 30;
  
  // Shared Preferences Keys
  static const String prefUserId = 'user_id';
  static const String prefUserRole = 'user_role';
  static const String prefIsLoggedIn = 'is_logged_in';
  static const String prefTrackingEnabled = 'tracking_enabled';
  static const String prefAutoOffTime = 'auto_off_time';
  
  // Animation Durations
  static const Duration animationFast = Duration(milliseconds: 200);
  static const Duration animationNormal = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);
}
