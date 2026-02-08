import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

/// Live map screen showing faculty locations
class StudentMapScreen extends StatefulWidget {
  final String? initialFacultyId;
  
  const StudentMapScreen({
    super.key,
    this.initialFacultyId,
  });
  
  @override
  State<StudentMapScreen> createState() => _StudentMapScreenState();
}

class _StudentMapScreenState extends State<StudentMapScreen> {
  FacultyWithLocation? _selectedFaculty;
  LatLng? _userLocation;
  bool _use3DMap = !kIsWeb; // Default to 2D on web (MapLibre workers unsupported on static hosts)
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String? _selectedCampusId; // Currently viewed campus
  bool _showLegend = false; // Collapsed legend by default
  
  // Key to force map recreation when campus changes
  Key _mapKey = UniqueKey();
  
  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    
    // Set initial campus from user's profile and recreate map
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final userCampusId = authProvider.user?.campusId ?? AppConstants.defaultCampusId;
      setState(() {
        _selectedCampusId = userCampusId;
        _mapKey = UniqueKey(); // Force map recreation with user's campus
      });
    });
    
    // If initialFacultyId is provided, select that faculty after build
    if (widget.initialFacultyId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final provider = context.read<FacultyProvider>();
        final faculty = provider.getFacultyById(widget.initialFacultyId!);
        if (faculty != null) {
          setState(() {
            _selectedFaculty = faculty;
          });
          // Focus on this faculty
          provider.setFocusedFaculty(widget.initialFacultyId);
        }
      });
    }
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    // Note: Don't access context.read() in dispose - it's unsafe
    // The FacultyProvider will handle cleanup when the widget is unmounted
    super.dispose();
  }
  
  Future<void> _getCurrentLocation() async {
    final locationProvider = context.read<LocationProvider>();
    final position = await locationProvider.getCurrentPosition();
    if (position != null && mounted) {
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final currentCampusId = _selectedCampusId ?? AppConstants.defaultCampusId;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_use3DMap ? '3D Campus Map' : 'Campus Map'),
        actions: [
          // Toggle 2D/3D (only on native, MapLibre workers don't work on web static hosts)
          if (!kIsWeb)
            IconButton(
              icon: Icon(_use3DMap ? Icons.map : Icons.threed_rotation),
              onPressed: () {
                setState(() {
                  _use3DMap = !_use3DMap;
                });
              },
              tooltip: _use3DMap ? 'Switch to 2D' : 'Switch to 3D',
            ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
            tooltip: 'My Location',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<FacultyProvider>().refresh();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map - either 3D or 2D
          Consumer2<FacultyProvider, AuthProvider>(
            builder: (context, facultyProvider, authProvider, _) {
              // Use mapFaculty to respect focused faculty (search result)
              final displayFaculty = facultyProvider.mapFaculty
                  .where((f) => f.isOnline)
                  .toList();
              
              if (_use3DMap) {
                // 3D MapLibre GL Map
                return CampusMap3D(
                  key: _mapKey,
                  faculty: displayFaculty,
                  userLocation: _userLocation != null 
                      ? maplibre.LatLng(_userLocation!.latitude, _userLocation!.longitude)
                      : null,
                  selectedFaculty: _selectedFaculty,
                  onMarkerTap: (faculty) {
                    setState(() {
                      _selectedFaculty = faculty;
                    });
                  },
                  showCampusBoundary: true,
                  enable3DBuildings: true,
                  campusId: currentCampusId,
                );
              } else {
                // 2D Flutter Map (OpenStreetMap)
                return CampusMap(
                  key: _mapKey,
                  faculty: displayFaculty,
                  userLocation: _userLocation,
                  selectedLocation: _selectedFaculty?.location?.latLng,
                  selectedFaculty: _selectedFaculty,
                  onMarkerTap: (faculty) {
                    setState(() {
                      _selectedFaculty = faculty;
                    });
                  },
                  showCampusBoundary: true,
                  campusId: currentCampusId,
                );
              }
            },
          ),
          
          // Top controls row: Search + Campus selector
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Row(
              children: [
                // Search bar (expandable)
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search faculty...',
                        hintStyle: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: AppColors.textSecondary,
                          size: 22,
                        ),
                        suffixIcon: _isSearching
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _isSearching = false;
                                  });
                                  context.read<FacultyProvider>().clearFocusedFaculty();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      style: const TextStyle(fontSize: 14),
                      onChanged: (value) {
                        setState(() {
                          _isSearching = value.isNotEmpty;
                        });
                        context.read<FacultyProvider>().search(value);
                      },
                      onSubmitted: (value) {
                        if (value.isNotEmpty) {
                          final provider = context.read<FacultyProvider>();
                          if (provider.filteredFaculty.isNotEmpty) {
                            final firstMatch = provider.filteredFaculty.first;
                            provider.setFocusedFaculty(firstMatch.user.id);
                            setState(() {
                              _selectedFaculty = firstMatch;
                            });
                          }
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Campus selector dropdown
                CampusSelector(
                  selectedCampusId: currentCampusId,
                  onCampusSelected: (campusId) {
                    setState(() {
                      _selectedCampusId = campusId;
                      _mapKey = UniqueKey(); // Force map recreation
                    });
                  },
                  compact: true,
                ),
              ],
            ),
          ),
          
          // Bottom left: Campus legend with navigation
          Positioned(
            bottom: _selectedFaculty != null ? 180 : 16,
            left: 12,
            child: CampusLegend(
              expanded: _showLegend,
              selectedCampusId: currentCampusId,
              onToggle: () {
                setState(() {
                  _showLegend = !_showLegend;
                });
              },
              onCampusSelected: (campusId) {
                setState(() {
                  _selectedCampusId = campusId;
                  _mapKey = UniqueKey(); // Force map recreation
                });
              },
            ),
          ),
          
          // Selected faculty bottom sheet
          if (_selectedFaculty != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: FacultyMapBottomSheet(
                faculty: _selectedFaculty!,
                distanceText: _getDistanceText(_selectedFaculty!),
                walkingTimeText: _getWalkingTimeText(_selectedFaculty!),
                onNavigate: () => _openDirections(_selectedFaculty!),
                onPing: () => _pingFaculty(_selectedFaculty!),
                onClose: () {
                  setState(() {
                    _selectedFaculty = null;
                  });
                },
              ),
            ),
        ],
      ),
      floatingActionButton: _selectedFaculty == null
          ? FloatingActionButton.extended(
              onPressed: () {
                _showFacultyListSheet();
              },
              icon: const Icon(Icons.list),
              label: const Text('List View'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }
  
  String? _getDistanceText(FacultyWithLocation faculty) {
    if (_userLocation == null || faculty.location == null) return null;
    
    final distance = const Distance().as(
      LengthUnit.Meter,
      _userLocation!,
      faculty.location!.latLng,
    );
    
    if (distance < 1000) {
      return '${distance.toInt()}m';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)}km';
    }
  }
  
  String? _getWalkingTimeText(FacultyWithLocation faculty) {
    if (_userLocation == null || faculty.location == null) return null;
    
    final distance = const Distance().as(
      LengthUnit.Meter,
      _userLocation!,
      faculty.location!.latLng,
    );
    
    // Average walking speed: 83.33 m/min
    final minutes = (distance / 83.33).ceil();
    
    if (minutes < 1) {
      return 'Less than 1 min';
    } else if (minutes == 1) {
      return '1 min';
    } else {
      return '$minutes mins';
    }
  }
  
  void _showFacultyListSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Consumer<FacultyProvider>(
                builder: (context, provider, _) {
                  final onlineFaculty = provider.allFaculty
                      .where((f) => f.isOnline)
                      .toList();
                  
                  return Column(
                    children: [
                      // Handle
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      
                      // Header
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.people,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Online Faculty (${onlineFaculty.length})',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const Divider(height: 1),
                      
                      // List
                      Expanded(
                        child: onlineFaculty.isEmpty
                            ? const EmptyState(
                                icon: Icons.location_off,
                                title: 'No faculty online',
                                message: 'Check back later for available faculty',
                              )
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: onlineFaculty.length,
                                itemBuilder: (context, index) {
                                  final faculty = onlineFaculty[index];
                                  return FacultyCard(
                                    faculty: faculty,
                                    showDistance: true,
                                    distanceText: _getDistanceText(faculty),
                                    onTap: () {
                                      Navigator.pop(context);
                                      setState(() {
                                        _selectedFaculty = faculty;
                                      });
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
  
  /// Focus on faculty location and show directions info
  void _openDirections(FacultyWithLocation faculty) {
    if (faculty.location == null) return;
    
    // Focus the map on this faculty
    context.read<FacultyProvider>().setFocusedFaculty(faculty.user.id);
    
    // Show a snackbar with helpful info
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.location_on, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Showing ${faculty.user.firstName}\'s location',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
  
  /// Send a "looking for you" ping to a faculty member
  Future<void> _pingFaculty(FacultyWithLocation faculty) async {
    final authProvider = context.read<AuthProvider>();
    final notificationProvider = context.read<NotificationProvider>();
    
    final currentUser = authProvider.user;
    if (currentUser == null) return;
    
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.notifications_active, color: AppColors.info),
            ),
            const SizedBox(width: 12),
            const Text('Notify Teacher'),
          ],
        ),
        content: Text(
          'Send a notification to ${faculty.user.firstName} that you\'re looking for them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.send, size: 18),
            label: const Text('Send'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.info,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
    
    if (confirmed != true || !mounted) return;
    
    try {
      final success = await notificationProvider.pingStaff(
        student: currentUser,
        staffId: faculty.user.id,
        staffName: faculty.user.fullName,
      );
      
      if (!success && mounted) {
        // Show error if there was one (like spam prevention)
        if (notificationProvider.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(notificationProvider.error!)),
                ],
              ),
              backgroundColor: AppColors.warning,
              behavior: SnackBarBehavior.floating,
            ),
          );
          notificationProvider.clearError();
          return;
        }
      }
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Notification sent to ${faculty.user.firstName}'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(e.toString())),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
