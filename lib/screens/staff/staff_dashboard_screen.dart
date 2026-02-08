import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/providers.dart';
import 'staff_settings_screen.dart';
import 'staff_map_screen.dart';
import 'staff_directory_screen.dart';
import 'notifications_screen.dart';

/// Main dashboard for staff/faculty members
class StaffDashboardScreen extends StatefulWidget {
  const StaffDashboardScreen({super.key});
  
  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen> with WidgetsBindingObserver {
  bool _isShowingBackgroundDialog = false;
  
  @override
  void initState() {
    super.initState();
    // Add lifecycle observer
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize location provider for staff with their campus
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.user != null) {
        context.read<LocationProvider>().initialize(
          authProvider.user!.id,
          campusId: authProvider.user!.campusId,
        );
      }
    });
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // When app is about to be hidden/paused
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      final locationProvider = context.read<LocationProvider>();
      
      // If tracking is on and we haven't shown the dialog yet
      if (locationProvider.isTracking && !_isShowingBackgroundDialog && !locationProvider.isBackgroundTrackingEnabled) {
        // We can't show dialog when going to background, so just enable background tracking
        // The dialog will be shown when user returns
      }
    }
    
    // When app resumes from background
    if (state == AppLifecycleState.resumed) {
      final locationProvider = context.read<LocationProvider>();
      
      // Refresh location data
      if (locationProvider.isTracking) {
        // Location is still tracking in background
        debugPrint('📍 App resumed - location tracking active');
      }
    }
  }
  
  /// Show dialog asking about background location sharing
  Future<bool> _showBackgroundTrackingDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.location_on, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            const Text('Continue Sharing?'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Do you want to continue sharing your location with students while the app is in the background?',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 12),
            Text(
              'Students will still be able to see your location on the map.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stop Sharing'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Continue Sharing'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }
  
  /// Handle back button press
  Future<bool> _onWillPop() async {
    final locationProvider = context.read<LocationProvider>();
    
    // If location sharing is active, show the background dialog
    if (locationProvider.isTracking) {
      _isShowingBackgroundDialog = true;
      final continueSharing = await _showBackgroundTrackingDialog();
      _isShowingBackgroundDialog = false;
      
      if (continueSharing) {
        // Enable background tracking and minimize app
        await locationProvider.enableBackgroundTracking();
        // Show a snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.location_on, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Location sharing continues in background'),
                ],
              ),
              backgroundColor: AppColors.primary,
              duration: Duration(seconds: 2),
            ),
          );
        }
        // Minimize app (go to home)
        SystemNavigator.pop();
        return false;
      } else {
        // Stop tracking and allow exit
        await locationProvider.stopTracking();
        return true;
      }
    }
    
    return true;
  }
  
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(AppConstants.appName),
          actions: [
            // Background tracking indicator
            Consumer<LocationProvider>(
              builder: (context, locationProvider, _) {
                if (locationProvider.isBackgroundTrackingEnabled) {
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on, color: AppColors.primary, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'BG',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            // Notification bell icon with badge
            Consumer<NotificationProvider>(
              builder: (context, notificationProvider, _) {
                return Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        );
                      },
                    ),
                    if (notificationProvider.unreadCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            notificationProvider.unreadCount > 9 
                                ? '9+' 
                                : notificationProvider.unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StaffSettingsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
        body: Consumer2<AuthProvider, LocationProvider>(
          builder: (context, authProvider, locationProvider, _) {
            final user = authProvider.user;
            
            if (user == null) {
              return const Center(
                child: Text('No user data available'),
              );
            }
          
          return RefreshIndicator(
            onRefresh: () async {
              // Refresh user data
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Welcome card with campus info
                  _buildWelcomeCard(context, user.firstName, user.campusId),
                  
                  const SizedBox(height: 20),
                  
                  // Location sharing toggle
                  _buildLocationSharingCard(context, locationProvider),
                  
                  const SizedBox(height: 20),
                  
                  // Status selection
                  _buildStatusCard(context, locationProvider),
                  
                  const SizedBox(height: 20),
                  
                  // Quick messages
                  _buildQuickMessagesCard(context, locationProvider),
                  
                  const SizedBox(height: 20),
                  
                  // Stats card
                  _buildStatsCard(context, locationProvider),
                  
                  const SizedBox(height: 20),
                  
                  // Map button for manual pinning - Enhanced
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.map_outlined, color: AppColors.primary),
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Location Management',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'View or manually set your location',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildMapActionButton(
                                  icon: Icons.gps_fixed,
                                  label: 'GPS Mode',
                                  subtitle: 'Auto-track',
                                  color: AppColors.primary,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const StaffMapScreen(use3D: false, useManualPin: false)),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildMapActionButton(
                                  icon: Icons.touch_app,
                                  label: 'Pin Mode',
                                  subtitle: 'Set manually',
                                  color: AppColors.accent,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const StaffMapScreen(use3D: false, useManualPin: true)),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildMapActionButton(
                                  icon: Icons.view_in_ar,
                                  label: '3D View',
                                  subtitle: 'Campus map',
                                  color: AppColors.info,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const StaffMapScreen(use3D: true, useManualPin: false)),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Find Colleagues card
                  Card(
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const StaffDirectoryScreen()),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: AppColors.accentGradient,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.people, color: Colors.white, size: 26),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Find Colleagues',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Locate other staff members on campus',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Sign out button
                  OutlinedButton.icon(
                    onPressed: () {
                      _showSignOutDialog(context);
                    },
                    icon: const Icon(Icons.logout, color: AppColors.error),
                    label: const Text(
                      'Sign Out',
                      style: TextStyle(color: AppColors.error),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
    );
  }
  
  Widget _buildWelcomeCard(BuildContext context, String firstName, String campusId) {
    final hour = DateTime.now().hour;
    String greeting;
    IconData icon;
    
    if (hour < 12) {
      greeting = 'Good Morning';
      icon = Icons.wb_sunny;
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
      icon = Icons.wb_cloudy;
    } else {
      greeting = 'Good Evening';
      icon = Icons.nightlight_round;
    }
    
    // Get campus display name
    final campus = AppConstants.getCampusById(campusId);
    final campusName = campus?['shortName'] ?? 'Unknown Campus';
    
    return Card(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        greeting,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_city,
                              color: Colors.white.withValues(alpha: 0.9),
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              campusName,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    firstName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLocationSharingCard(
    BuildContext context,
    LocationProvider locationProvider,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: locationProvider.isTracking
                        ? AppColors.accent.withValues(alpha: 0.1)
                        : AppColors.textSecondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    locationProvider.isTracking
                        ? Icons.location_on
                        : Icons.location_off,
                    color: locationProvider.isTracking
                        ? AppColors.accent
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Location Sharing',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        locationProvider.isTracking
                            ? 'Your location is visible to students'
                            : 'Your location is hidden',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: locationProvider.isTracking,
                  onChanged: (value) {
                    if (value) {
                      locationProvider.startTracking();
                    } else {
                      locationProvider.stopTracking();
                    }
                  },
                  activeTrackColor: AppColors.accent.withValues(alpha: 0.5),
                  thumbColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return AppColors.accent;
                    }
                    return null;
                  }),
                ),
              ],
            ),
            
            if (locationProvider.isTracking) ...[
              const Divider(height: 24),
              
              // Location info
              Row(
                children: [
                  Icon(
                    locationProvider.isWithinCampus
                        ? Icons.check_circle
                        : Icons.warning,
                    color: locationProvider.isWithinCampus
                        ? AppColors.accent
                        : AppColors.warning,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    locationProvider.isWithinCampus
                        ? 'You are within campus boundaries'
                        : 'You are outside campus boundaries',
                    style: TextStyle(
                      color: locationProvider.isWithinCampus
                          ? AppColors.accent
                          : AppColors.warning,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              
              if (locationProvider.lastUpdate != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.update,
                      color: AppColors.textSecondary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Last updated: ${_formatTime(locationProvider.lastUpdate!)}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
              
              // Background tracking indicator
              if (locationProvider.isBackgroundTrackingEnabled) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.sync, color: AppColors.primary, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Background sharing enabled - location updates even when app is closed',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () async {
                          await locationProvider.disableBackgroundTracking();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Background tracking disabled'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        child: const Icon(Icons.close, color: AppColors.primary, size: 18),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatusCard(
    BuildContext context,
    LocationProvider locationProvider,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Status',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppConstants.statusPresets.map((status) {
                final isSelected = locationProvider.currentStatus == status;
                return ChoiceChip(
                  label: Text(status),
                  selected: isSelected,
                  onSelected: locationProvider.isTracking
                      ? (_) {
                          locationProvider.setStatus(status);
                        }
                      : null,
                  selectedColor: AppColors.getStatusColor(status).withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? AppColors.getStatusColor(status)
                        : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.getStatusColor(status)
                        : AppColors.border,
                  ),
                );
              }).toList(),
            ),
            
            if (!locationProvider.isTracking) ...[
              const SizedBox(height: 12),
              Text(
                'Enable location sharing to update your status',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildQuickMessagesCard(
    BuildContext context,
    LocationProvider locationProvider,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Quick Message',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (locationProvider.currentMessage != null)
                  TextButton(
                    onPressed: locationProvider.isTracking
                        ? () {
                            locationProvider.setQuickMessage(null);
                          }
                        : null,
                    child: const Text('Clear'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            
            if (locationProvider.currentMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.info.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.chat_bubble, color: AppColors.info, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '"${locationProvider.currentMessage}"',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppConstants.quickMessages.map((message) {
                final isSelected = locationProvider.currentMessage == message;
                return ActionChip(
                  label: Text(message),
                  onPressed: locationProvider.isTracking
                      ? () {
                          if (isSelected) {
                            locationProvider.setQuickMessage(null);
                          } else {
                            locationProvider.setQuickMessage(message);
                          }
                        }
                      : null,
                  backgroundColor: isSelected
                      ? AppColors.info.withValues(alpha: 0.15)
                      : null,
                  side: BorderSide(
                    color: isSelected ? AppColors.info : AppColors.border,
                  ),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 12),
            
            // Custom message
            TextButton.icon(
              onPressed: locationProvider.isTracking
                  ? () => _showCustomMessageDialog(context, locationProvider)
                  : null,
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Custom Message'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatsCard(
    BuildContext context,
    LocationProvider locationProvider,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today\'s Summary',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.timer,
                    value: '${locationProvider.trackingDurationMinutes} min',
                    label: 'Active Time',
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.location_on,
                    value: locationProvider.isWithinCampus ? 'On' : 'Off',
                    label: 'Campus',
                    color: locationProvider.isWithinCampus
                        ? AppColors.accent
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} min ago';
    } else {
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
  
  void _showCustomMessageDialog(
    BuildContext context,
    LocationProvider locationProvider,
  ) {
    final controller = TextEditingController(
      text: locationProvider.currentMessage,
    );
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom Message'),
        content: TextField(
          controller: controller,
          maxLength: 100,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: 'Enter a short message...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              locationProvider.setQuickMessage(
                controller.text.trim().isEmpty ? null : controller.text.trim(),
              );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
  
  void _showSignOutDialog(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final locationProvider = context.read<LocationProvider>();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
          'Are you sure you want to sign out? Your location sharing will be stopped.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              locationProvider.stopTracking();
              await authProvider.signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMapActionButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: color.withValues(alpha: 0.7),
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
