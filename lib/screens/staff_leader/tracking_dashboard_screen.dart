import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';

/// Tracking & Status Dashboard for Student Leaders and Organization Officers
class TrackingDashboardScreen extends StatefulWidget {
  const TrackingDashboardScreen({super.key});

  @override
  State<TrackingDashboardScreen> createState() =>
      _TrackingDashboardScreenState();
}

class _TrackingDashboardScreenState extends State<TrackingDashboardScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Ensure location provider is initialized
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
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final locationProvider = context.watch<LocationProvider>();

    if (authProvider.user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = authProvider.user!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tracking & Status'),
        actions: [
          if (locationProvider.isTracking)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => locationProvider.startTracking(),
              tooltip: 'Refresh location now',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Card
            _buildHeaderCard(user, locationProvider),

            const SizedBox(height: 24),

            // Tracking Toggle
            _buildTrackingCard(locationProvider),

            const SizedBox(height: 16),

            // Status and visibility are independent from location tracking.
            _buildStatusCard(locationProvider),
            const SizedBox(height: 16),
            _buildQuickMessageCard(locationProvider),
            const SizedBox(height: 16),
            _buildBroadcastScopeCard(locationProvider),
            const SizedBox(height: 16),
            _buildOfficeHoursCard(user),

            const SizedBox(height: 24),

            // Tracking Info
            _buildTrackingInfoCard(locationProvider),

            const SizedBox(height: 24),

            // Background Tracking
            _buildBackgroundTrackingCard(locationProvider),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(UserModel user, LocationProvider locationProvider) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: Text(
                user.initials,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              user.fullName,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              user.roleString,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (user.department != null) ...[
              const SizedBox(height: 2),
              Text(
                user.department!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 16),
            // Live Status Indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: locationProvider.isTracking
                    ? AppColors.success.withValues(alpha: 0.1)
                    : AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: locationProvider.isTracking
                          ? AppColors.success
                          : AppColors.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    locationProvider.isTracking
                        ? 'Tracking Active'
                        : 'Tracking Paused',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: locationProvider.isTracking
                          ? AppColors.success
                          : AppColors.error,
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

  Widget _buildTrackingCard(LocationProvider locationProvider) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: AppColors.primary, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Location Sharing',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        locationProvider.isTracking ? 'Active' : 'Paused',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: locationProvider.isTracking
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                      ),
                      Text(
                        locationProvider.isTracking
                            ? 'Your location is visible to students'
                            : 'Students cannot see your location',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: locationProvider.isTracking,
                  onChanged: _isLoading
                      ? null
                      : (value) => _toggleTracking(locationProvider, value),
                  activeThumbColor: AppColors.primary,
                  activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
                ),
              ],
            ),
            if (locationProvider.isTracking) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoChip(
                      Icons.access_time,
                      '${locationProvider.trackingDurationMinutes} min',
                      'Tracking duration',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildInfoChip(
                      Icons.map,
                      locationProvider.isWithinCampus
                          ? 'On Campus'
                          : 'Off Campus',
                      'Campus status',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildInfoChip(
                      Icons.directions_walk,
                      locationProvider.isMoving ? 'Moving' : 'Stationary',
                      'Movement',
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(LocationProvider locationProvider) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag, color: AppColors.primary, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Current Status',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Current: ${locationProvider.currentStatus}',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            if (locationProvider.statusExpiresAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Expires ${_formatStatusExpiry(locationProvider.statusExpiresAt!)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              'Set expiration',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _statusDurationChip(
                  locationProvider,
                  '30m',
                  const Duration(minutes: 30),
                ),
                _statusDurationChip(
                  locationProvider,
                  '1h',
                  const Duration(hours: 1),
                ),
                _statusDurationChip(
                  locationProvider,
                  '2h',
                  const Duration(hours: 2),
                ),
                _statusDurationChip(
                  locationProvider,
                  '4h',
                  const Duration(hours: 4),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Quick Set Status',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppConstants.statusPresets.map((status) {
                final isSelected = locationProvider.currentStatus == status;
                return ChoiceChip(
                  label: Text(status),
                  selected: isSelected,
                  onSelected: (_) => _setStatus(locationProvider, status),
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textPrimary,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickMessageCard(LocationProvider locationProvider) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  color: AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Quick Message',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              locationProvider.currentMessage ?? 'No message set',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
                color: locationProvider.currentMessage != null
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Quick Messages',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...AppConstants.quickMessages.map(
                  (msg) => ActionChip(
                    label: Text(msg),
                    onPressed: () => _setQuickMessage(locationProvider, msg),
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    labelStyle: const TextStyle(color: AppColors.primary),
                  ),
                ),
                ActionChip(
                  label: const Text('Clear'),
                  onPressed: () => _setQuickMessage(locationProvider, null),
                  backgroundColor: AppColors.error.withValues(alpha: 0.1),
                  labelStyle: const TextStyle(color: AppColors.error),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusDurationChip(
    LocationProvider provider,
    String label,
    Duration duration,
  ) {
    return ActionChip(
      label: Text(label),
      onPressed: () =>
          provider.setStatus(provider.currentStatus, duration: duration),
    );
  }

  Widget _buildBroadcastScopeCard(LocationProvider locationProvider) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.public, color: AppColors.primary, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Location Broadcast',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Choose who can see your live campus location.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            RadioGroup<LocationVisibilityScope>(
              groupValue: locationProvider.visibilityScope,
              onChanged: (value) {
                if (value != null) locationProvider.setVisibilityScope(value);
              },
              child: Column(
                children: [
                  const RadioListTile<LocationVisibilityScope>(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Campus only'),
                    subtitle: Text('Visible within your assigned campus'),
                    value: LocationVisibilityScope.campusOnly,
                  ),
                  const RadioListTile<LocationVisibilityScope>(
                    contentPadding: EdgeInsets.zero,
                    title: Text('University wide'),
                    subtitle: Text('Visible across all SKSU campuses'),
                    value: LocationVisibilityScope.universityWide,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatStatusExpiry(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour == 0
        ? 12
        : (local.hour > 12 ? local.hour - 12 : local.hour);
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  Widget _buildOfficeHoursCard(UserModel user) {
    final officeHours = user.officeHours;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, color: AppColors.primary, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Office Hours',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (officeHours != null && officeHours.isNotEmpty) ...[
              Column(
                children: officeHours
                    .map(
                      (slot) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                slot,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ] else ...[
              Text(
                'No office hours set',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/edit-profile'),
                icon: const Icon(Icons.edit),
                label: const Text('Set Office Hours'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingInfoCard(LocationProvider locationProvider) {
    if (!locationProvider.isTracking) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.primary, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Tracking Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              'Last Update',
              locationProvider.lastUpdate?.toString() ?? 'Never',
            ),
            _buildInfoRow(
              'Accuracy',
              '${locationProvider.currentLocation?.accuracy?.toStringAsFixed(1) ?? 'N/A'} m',
            ),
            _buildInfoRow(
              'Campus',
              locationProvider.userCampusId ?? AppConstants.defaultCampusId,
            ),
            if (locationProvider.currentLocation?.isManualPin == true)
              _buildInfoRow('Mode', 'Manual Pin (GPS paused)'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundTrackingCard(LocationProvider locationProvider) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.nightlight_round,
                  color: AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Background Tracking',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              kIsWeb
                  ? 'Browser tracking remains active while this tab is open. '
                        'Use the mobile app for continuous background tracking.'
                  : 'Keep location sharing active while the mobile app is in the background. '
                        'This may use more battery.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        locationProvider.isBackgroundTrackingEnabled
                            ? 'Enabled'
                            : 'Disabled',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color:
                                  locationProvider.isBackgroundTrackingEnabled
                                  ? AppColors.success
                                  : AppColors.textSecondary,
                            ),
                      ),
                      Text(
                        locationProvider.isBackgroundTrackingEnabled
                            ? 'Location updates continue in background'
                            : 'Location only updates when app is open',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  onChanged: kIsWeb
                      ? null
                      : (value) => value
                            ? locationProvider.enableBackgroundTracking()
                            : locationProvider.disableBackgroundTracking(),
                  value: locationProvider.isBackgroundTrackingEnabled,
                  activeThumbColor: AppColors.primary,
                  activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
                ),
              ],
            ),
            if (locationProvider.isBackgroundTrackingEnabled)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Note: Background tracking may use more battery. '
                  'Auto-hide schedule (if set) will still pause tracking at configured times.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.warning),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleTracking(LocationProvider provider, bool enable) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      if (enable) {
        await provider.startTracking();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Location sharing started'),
                ],
              ),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        await provider.stopTracking();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.pause_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Location sharing stopped'),
                ],
              ),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error: $e')),
              ],
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _setStatus(LocationProvider provider, String status) async {
    try {
      await provider.setStatus(status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status set to "$status"'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _setQuickMessage(
    LocationProvider provider,
    String? message,
  ) async {
    try {
      await provider.setQuickMessage(message);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message != null ? 'Quick message set' : 'Quick message cleared',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
