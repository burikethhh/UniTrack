import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/utils/connectivity_service.dart';
import 'core/utils/web_utils.dart';
import 'providers/providers.dart';
import 'services/services.dart';
import 'models/models.dart';
import 'screens/screens.dart';
import 'screens/onboarding/onboarding_screen.dart';

// Demo mode flag - set to false to use Firebase
const bool kDemoMode = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Catch and log all initialization errors (helpful for web debugging)
  try {
    await _initializeApp();
  } catch (e, stack) {
    debugPrint('💥 FATAL initialization error: $e');
    debugPrint('$stack');
    // On web, show a visible error instead of white screen
    if (kIsWeb) {
      runApp(MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'App initialization error:\n$e',
                style: const TextStyle(color: Colors.red, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ));
      return;
    }
    rethrow;
  }
  
  runApp(const UniTrackApp());
}

Future<void> _initializeApp() async {
  // Set preferred orientations (mobile only)
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    
    // Set system UI overlay style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Configure Firestore settings for web to avoid SDK internal errors
  if (kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }
  
  // Initialize connectivity monitoring (works on all platforms)
  ConnectivityService().startMonitoring();
  
  // Initialize offline cache service (SharedPreferences on web, sqflite on mobile)
  try {
    await OfflineCacheService().initialize();
  } catch (e) {
    debugPrint('⚠️ Offline cache init error (non-fatal): $e');
  }
  
  // Initialize push notifications (FCM on web, local notifications on mobile)
  try {
    await PushNotificationService().initialize();
  } catch (e) {
    debugPrint('⚠️ Push notification init error (non-fatal): $e');
  }
}

/// Custom scroll behavior that enables drag scrolling on all devices (web + touch)
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

class UniTrackApp extends StatelessWidget {
  const UniTrackApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Services
        Provider<AuthService>(
          create: (_) => AuthService(),
        ),
        Provider<LocationService>(
          create: (_) => LocationService(),
        ),
        Provider<DatabaseService>(
          create: (_) => DatabaseService(),
        ),
        Provider<NotificationService>(
          create: (_) => NotificationService(),
        ),
        Provider<OfflineCacheService>(
          create: (_) => OfflineCacheService(),
        ),
        Provider<PushNotificationService>(
          create: (_) => PushNotificationService(),
        ),
        
        // Providers
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(
            authService: context.read<AuthService>(),
            databaseService: context.read<DatabaseService>(),
          ),
        ),
        ChangeNotifierProvider<LocationProvider>(
          create: (context) => LocationProvider(
            locationService: context.read<LocationService>(),
          ),
        ),
        ChangeNotifierProvider<FacultyProvider>(
          create: (context) => FacultyProvider(
            databaseService: context.read<DatabaseService>(),
          ),
        ),
        ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>(
          create: (context) => NotificationProvider(
            context.read<NotificationService>(),
          ),
          update: (context, authProvider, notificationProvider) {
            final userId = authProvider.user?.id;
            if (userId != null && notificationProvider != null) {
              notificationProvider.initialize(userId);
            }
            return notificationProvider ?? NotificationProvider(
              context.read<NotificationService>(),
            );
          },
        ),
        // Admin Provider for super admin features
        ChangeNotifierProvider<AdminProvider>(
          create: (_) => AdminProvider(),
        ),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        scrollBehavior: AppScrollBehavior(),
        navigatorKey: notificationNavigatorKey,
        home: kDemoMode ? const DemoModeSelector() : const AppEntry(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/onboarding': (context) => const OnboardingScreen(),
        },
        // Responsive wrapper: constrain max width on tablets/desktops
        builder: (context, child) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: child,
            ),
          );
        },
      ),
    );
  }
}

/// App entry point with splash screen and onboarding check
class AppEntry extends StatefulWidget {
  const AppEntry({super.key});
  
  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  bool _showSplash = true;
  bool? _hasSeenOnboarding;
  
  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }
  
  Future<void> _checkOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _hasSeenOnboarding = prefs.getBool(OnboardingScreen.hasSeenOnboardingKey) ?? false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Skip Flutter splash on web — HTML splash already handles loading UX
    if (_showSplash && !kIsWeb) {
      return SplashScreen(
        onComplete: () {
          if (mounted) {
            setState(() => _showSplash = false);
          }
        },
      );
    }
    
    // Still checking onboarding status
    if (_hasSeenOnboarding == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    // Show onboarding for first-time users
    if (!_hasSeenOnboarding!) {
      return const OnboardingScreen();
    }
    
    return const AuthWrapper();
  }
}

/// Demo mode screen to select which role to preview
class DemoModeSelector extends StatelessWidget {
  const DemoModeSelector({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE8A87C),  // Peach
              Color(0xFF85DCBA),  // Light Mint Green
              Color(0xFF41B3A3),  // Sage Green
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 40),
                
                // Logo
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.location_on,
                    size: 50,
                    color: Color(0xFFE8A87C),  // Peach
                  ),
                ),
                const SizedBox(height: 24),
                
                const Text(
                  'UniTrack',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Demo Mode',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Firebase Not Configured',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                
                const SizedBox(height: 48),
                
                const Text(
                  'Select a role to preview:',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Role buttons
                _buildRoleButton(
                  context,
                  'Student',
                  'View faculty locations & navigate',
                  Icons.school,
                  Colors.blue,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StudentHomeScreen()),
                  ),
                ),
                const SizedBox(height: 16),
                
                _buildRoleButton(
                  context,
                  'Faculty / Staff',
                  'Manage your location sharing',
                  Icons.person,
                  Colors.green,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StaffDashboardScreen()),
                  ),
                ),
                const SizedBox(height: 16),
                
                _buildRoleButton(
                  context,
                  'Admin',
                  'View analytics & manage users',
                  Icons.admin_panel_settings,
                  Colors.purple,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SuperAdminDashboard()),
                  ),
                ),
                
                const Spacer(),
                
                Text(
                  '© 2026 SKSU • Version ${AppConstants.appVersion}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildRoleButton(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF003366),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[400],
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wrapper that handles auth state and routes to appropriate screen
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});
  
  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _hasCheckedForUpdates = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (kDebugMode) {
          debugPrint('🔄 AuthWrapper: isLoading=${authProvider.isLoading}, isAuth=${authProvider.isAuthenticated}, user=${authProvider.user?.email}');
        }
        
        // Show loading while checking auth state
        if (authProvider.isLoading) {
          if (kDebugMode) debugPrint('🔄 AuthWrapper: Showing LOADING screen');
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading...'),
                ],
              ),
            ),
          );
        }
        
        // Not authenticated - show login
        if (!authProvider.isAuthenticated) {
          if (kDebugMode) debugPrint('🔄 AuthWrapper: Showing LOGIN screen');
          return const LoginScreen();
        }
        
        // Authenticated - route based on role
        final user = authProvider.user;
        if (user == null) {
          if (kDebugMode) debugPrint('🔄 AuthWrapper: user is null, showing LOGIN');
          return const LoginScreen();
        }
        
        if (kDebugMode) debugPrint('🔄 AuthWrapper: Showing HOME for ${user.role}');
        
        // Check for updates on first authenticated build
        if (!_hasCheckedForUpdates) {
          _hasCheckedForUpdates = true;
          _checkForUpdates();
        }
        
        switch (user.role) {
          case UserRole.admin:
            return const SuperAdminDashboard();
          case UserRole.staff:
            return const StaffDashboardScreen();
          case UserRole.student:
            return const StudentHomeScreen();
        }
      },
    );
  }

  Future<void> _checkForUpdates() async {
    // Delay slightly to allow the home screen to build first
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    final updateService = UpdateService();
    final result = await updateService.checkForUpdate();
    
    if (!mounted) return;
    
    if (result.hasUpdate && result.latestVersion != null) {
      // Show update dialog
      // ignore: use_build_context_synchronously
      showDialog(
        context: context,
        barrierDismissible: !result.isRequired,
        builder: (_) => _StartupUpdateDialog(updateResult: result),
      );
    }
  }
}


/// Startup update dialog shown after app launch
class _StartupUpdateDialog extends StatefulWidget {
  final UpdateCheckResult updateResult;

  const _StartupUpdateDialog({required this.updateResult});

  @override
  State<_StartupUpdateDialog> createState() => _StartupUpdateDialogState();
}

class _StartupUpdateDialogState extends State<_StartupUpdateDialog> {
  final UpdateService _updateService = UpdateService();
  bool _isDownloading = false;
  double _downloadProgress = 0;
  String _statusMessage = '';

  @override
  Widget build(BuildContext context) {
    final version = widget.updateResult.latestVersion!;
    final theme = Theme.of(context);

    return PopScope(
      canPop: !widget.updateResult.isRequired || _isDownloading,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withAlpha(204),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(51),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.system_update,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Update Available!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'v${version.versionName}',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.updateResult.isRequired)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning, color: Colors.red.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This update is required to continue using the app.',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Version comparison
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(
                          children: [
                            const Text('Current', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text(
                              'v${_updateService.currentVersionName}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Icon(Icons.arrow_forward, color: Colors.grey),
                        ),
                        Column(
                          children: [
                            const Text('New', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text(
                              'v${version.versionName}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Release notes
                    if (version.releaseNotes != null) ...[
                      const SizedBox(height: 20),
                      const Text(
                        "What's New:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          version.releaseNotes!,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                    ],

                    // Download progress
                    if (_isDownloading) ...[
                      const SizedBox(height: 24),
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _statusMessage,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              Text(
                                '${(_downloadProgress * 100).toInt()}%',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: _downloadProgress,
                              minHeight: 10,
                              backgroundColor: Colors.grey.shade200,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: _isDownloading
            ? null
            : [
                if (!widget.updateResult.isRequired)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Later'),
                  ),
                ElevatedButton.icon(
                  icon: Icon(kIsWeb ? Icons.refresh : Icons.download),
                  label: Text(kIsWeb ? 'Refresh Now' : 'Update Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _startDownload,
                ),
              ],
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
      ),
    );
  }

  Future<void> _startDownload() async {
    final version = widget.updateResult.latestVersion!;

    setState(() {
      _isDownloading = true;
      _statusMessage = 'Downloading...';
    });

    final success = await _updateService.downloadAndInstallUpdate(
      version,
      onProgress: (progress) {
        setState(() {
          _downloadProgress = progress;
          if (progress < 1.0) {
            _statusMessage = 'Downloading...';
          } else {
            _statusMessage = 'Installing...';
          }
        });
      },
    );

    if (mounted) {
      if (success) {
        if (kIsWeb) {
          reloadWebPage();
        }
        Navigator.of(context).pop();
      } else {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Text('Download failed. Please try again.'),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
