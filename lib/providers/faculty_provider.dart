import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/database_service.dart';

/// Faculty Provider for student module
class FacultyProvider extends ChangeNotifier {
  final DatabaseService _databaseService;

  FacultyProvider({required DatabaseService databaseService})
    : _databaseService = databaseService;

  List<FacultyWithLocation> _allFaculty = [];
  List<FacultyWithLocation> _filteredFaculty = [];
  List<DepartmentModel> _departments = [];
  String _searchQuery = '';
  String? _selectedDepartment;
  String? _selectedOrganization; // <-- new: organization filter
  bool _showOnlineOnly = false;
  bool _isLoading = false;
  String? _error;

  // Campus filter - shows faculty from specific campus
  String? _campusFilter;

  // Focused faculty - when searching, only show this faculty on map
  String? _focusedFacultyId;

  // Availability status filter
  AvailabilityStatus? _selectedAvailabilityStatus;

  // Viewer role — controls privacy filtering of off-campus locations
  UserRole? _viewerRole;

  StreamSubscription? _facultySubscription;
  Timer? _refreshTimer;
  Timer? _retryTimer;
  int _retryCount = 0;
  static const int _maxRetries = 5;

  // ── Faculty-arrived detection ──
  final Set<String> _previouslyOnlineIds = {};
  bool _hasReceivedFirstSnapshot = false;
  final StreamController<FacultyWithLocation> _arrivalController =
      StreamController<FacultyWithLocation>.broadcast();

  /// Stream that emits every time a faculty member transitions offline → online.
  /// Consumers (e.g. student map) can listen to show toasts/notifications.
  Stream<FacultyWithLocation> get onFacultyArrived => _arrivalController.stream;

  // Getters
  List<FacultyWithLocation> get allFaculty => _allFaculty;
  List<FacultyWithLocation> get filteredFaculty => _filteredFaculty;
  List<DepartmentModel> get departments => _departments;
  String get searchQuery => _searchQuery;
  String? get selectedDepartment => _selectedDepartment;
  String? get selectedOrganization => _selectedOrganization;
  bool get showOnlineOnly => _showOnlineOnly;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get campusFilter => _campusFilter;
  String? get focusedFacultyId => _focusedFacultyId;
  AvailabilityStatus? get selectedAvailabilityStatus =>
      _selectedAvailabilityStatus;

  int get totalFaculty => _allFaculty.length;
  int get onlineFaculty => _allFaculty.where((f) => f.isOnline).length;

  /// Count faculty by availability status
  int countByStatus(AvailabilityStatus status) {
    return _allFaculty
        .where((f) => f.isOnline && f.user.availabilityStatus == status)
        .length;
  }

  /// Count of available faculty (online + Available status)
  int get availableFacultyCount {
    return _allFaculty
        .where(
          (f) =>
              f.isOnline &&
              f.user.availabilityStatus == AvailabilityStatus.available,
        )
        .length;
  }

  /// Get faculty to display on map (respects focused faculty)
  List<FacultyWithLocation> get mapFaculty {
    if (_focusedFacultyId != null) {
      // When searching for specific faculty, only show that faculty
      final focused = getFacultyById(_focusedFacultyId!);
      return focused != null ? [focused] : [];
    }
    // Otherwise show all filtered faculty
    return _filteredFaculty;
  }

  /// Get campus-filtered faculty
  List<FacultyWithLocation> get campusFaculty {
    if (_campusFilter == null) return _allFaculty;
    return _allFaculty.where((f) => f.user.campusId == _campusFilter).toList();
  }

  /// Initialize and start listening.
  /// [viewerRole] controls privacy filtering — students won't receive
  /// off-campus location coordinates.
  void initialize({UserRole? viewerRole}) {
    _viewerRole = viewerRole;
    _isLoading = true;
    notifyListeners();

    // Cancel any existing subscriptions/timers to prevent leaks
    _facultySubscription?.cancel();
    _refreshTimer?.cancel();

    // Listen to faculty updates with real-time changes
    _facultySubscription = _databaseService
        .getFacultyWithLocationsStream(viewerRole: _viewerRole)
        .listen(
          (faculty) {
            if (kDebugMode) {
              final online = faculty.where((f) => f.isOnline).length;
              final withLoc = faculty.where((f) => f.location != null).length;
              debugPrint(
                '[FacultyProvider] Stream: '
                'total=${faculty.length}, withLocation=$withLoc, online=$online',
              );
              for (final f in faculty) {
                debugPrint(
                  '  ${f.user.fullName} (${f.user.role}): '
                  'loc=${f.location != null}, '
                  'tracking=${f.user.isTrackingEnabled}, '
                  'stale=${f.isLocationStale}, '
                  'online=${f.isOnline}',
                );
              }
            }
            _allFaculty = faculty;

            // ── Faculty-arrived detection ──
            final currentOnlineIds = faculty
                .where((f) => f.isOnline)
                .map((f) => f.user.id)
                .toSet();
            if (_hasReceivedFirstSnapshot) {
              final newArrivals = currentOnlineIds.difference(
                _previouslyOnlineIds,
              );
              for (final id in newArrivals) {
                final arrived = faculty.firstWhere((f) => f.user.id == id);
                _arrivalController.add(arrived);
                debugPrint(
                  '[FacultyProvider] 🟢 Faculty arrived: ${arrived.user.fullName}',
                );
              }
            }
            _previouslyOnlineIds
              ..clear()
              ..addAll(currentOnlineIds);
            _hasReceivedFirstSnapshot = true;

            _applyFilters();
            _isLoading = false;
            _error = null;
            _retryCount = 0;
            _retryTimer?.cancel();
            notifyListeners();
          },
          onError: (e) {
            debugPrint('[FacultyProvider] Stream ERROR: $e');
            _error = e.toString();
            _isLoading = false;
            notifyListeners();
            // Auto-retry with exponential backoff
            _scheduleRetry();
          },
        );
    // Start periodic timer to re-evaluate staleness (every 30 seconds)
    // Only notifies if the filtered list actually changes
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      // Capture online states BEFORE re-filtering (shallow copy shares refs)
      final oldOnlineStates = {
        for (final f in _filteredFaculty) f.user.id: f.isOnline,
      };
      final oldLength = _filteredFaculty.length;
      _applyFilters();
      // Only rebuild widgets if the filtered results actually changed
      final changed =
          oldLength != _filteredFaculty.length ||
          _filteredFaculty.any((f) => oldOnlineStates[f.user.id] != f.isOnline);
      if (changed) {
        notifyListeners();
      }
    });

    // Load departments
    _loadDepartments();
  }

  /// Load departments
  Future<void> _loadDepartments() async {
    _departments = await _databaseService.getAllDepartments();
    notifyListeners();
  }

  /// Schedule a retry after stream error with exponential backoff
  void _scheduleRetry() {
    if (_retryCount >= _maxRetries) {
      debugPrint('Faculty stream: max retries reached');
      return;
    }
    final delay = Duration(
      seconds: 5 * (1 << _retryCount),
    ); // 5s, 10s, 20s, 40s, 80s
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      _retryCount++;
      debugPrint(
        'Faculty stream: retry #$_retryCount after ${delay.inSeconds}s',
      );
      initialize();
    });
  }

  /// Search faculty
  void search(String query) {
    _searchQuery = query;
    _applyFilters();
    notifyListeners();
  }

  /// Set focused faculty for map display (only show this faculty's marker)
  void setFocusedFaculty(String? facultyId) {
    _focusedFacultyId = facultyId;
    notifyListeners();
  }

  /// Clear focused faculty (show all markers again)
  void clearFocusedFaculty() {
    _focusedFacultyId = null;
    notifyListeners();
  }

  /// Set campus filter
  void setCampusFilter(String? campusId) {
    _campusFilter = campusId;
    _applyFilters();
    notifyListeners();
  }

  /// Filter by department
  void filterByDepartment(String? department) {
    _selectedDepartment = department;
    _applyFilters();
    notifyListeners();
  }

  /// Filter by organization
  void filterByOrganization(String? organization) {
    _selectedOrganization = organization;
    _applyFilters();
    notifyListeners();
  }

  /// Get unique organizations from all faculty
  List<String> get organizations {
    final orgs = <String>{};
    for (final f in _allFaculty) {
      if (f.user.organization != null && f.user.organization!.isNotEmpty) {
        orgs.add(f.user.organization!);
      }
    }
    final sorted = orgs.toList()..sort();
    return sorted;
  }

  /// Toggle online only filter
  void toggleOnlineOnly() {
    _showOnlineOnly = !_showOnlineOnly;
    _applyFilters();
    notifyListeners();
  }

  /// Filter by availability status
  void filterByAvailabilityStatus(AvailabilityStatus? status) {
    _selectedAvailabilityStatus = status;
    // If filtering by status, also show online only
    if (status != null) {
      _showOnlineOnly = true;
    }
    _applyFilters();
    notifyListeners();
  }

  /// Clear all filters
  void clearFilters() {
    _searchQuery = '';
    _selectedDepartment = null;
    _selectedOrganization = null;
    _showOnlineOnly = false;
    _selectedAvailabilityStatus = null;
    _focusedFacultyId = null; // Also clear focused faculty
    _applyFilters();
    notifyListeners();
  }

  /// Apply all filters
  void _applyFilters() {
    // Start with campus-filtered faculty if campus filter is set
    List<FacultyWithLocation> baseList = _campusFilter != null
        ? _allFaculty.where((f) => f.user.campusId == _campusFilter).toList()
        : _allFaculty;

    _filteredFaculty = baseList.where((faculty) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesName = faculty.user.fullName.toLowerCase().contains(query);
        final matchesDept =
            faculty.user.department?.toLowerCase().contains(query) ?? false;
        final matchesPosition =
            faculty.user.position?.toLowerCase().contains(query) ?? false;

        if (!matchesName && !matchesDept && !matchesPosition) {
          return false;
        }
      }

      // Department filter
      if (_selectedDepartment != null && _selectedDepartment!.isNotEmpty) {
        if (faculty.user.department != _selectedDepartment) {
          return false;
        }
      }

      // Organization filter
      if (_selectedOrganization != null && _selectedOrganization!.isNotEmpty) {
        if (faculty.user.organization != _selectedOrganization) {
          return false;
        }
      }

      // Online filter
      if (_showOnlineOnly && !faculty.isOnline) {
        return false;
      }

      // Availability status filter
      if (_selectedAvailabilityStatus != null) {
        if (faculty.user.availabilityStatus != _selectedAvailabilityStatus) {
          return false;
        }
      }

      return true;
    }).toList();

    // Sort: online first, then by name
    _filteredFaculty.sort((a, b) {
      if (a.isOnline && !b.isOnline) return -1;
      if (!a.isOnline && b.isOnline) return 1;
      return a.user.fullName.compareTo(b.user.fullName);
    });
  }

  /// Get faculty by ID
  FacultyWithLocation? getFacultyById(String id) {
    try {
      return _allFaculty.firstWhere((f) => f.user.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Refresh data by re-subscribing to the stream
  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();

    // Cancel existing subscription and re-subscribe
    await _facultySubscription?.cancel();
    _facultySubscription = _databaseService
        .getFacultyWithLocationsStream(viewerRole: _viewerRole)
        .listen(
          (faculty) {
            _allFaculty = faculty;

            // ── Faculty-arrived detection (mirrors initialize listener) ──
            final currentOnlineIds = faculty
                .where((f) => f.isOnline)
                .map((f) => f.user.id)
                .toSet();
            if (_hasReceivedFirstSnapshot) {
              final newArrivals = currentOnlineIds.difference(
                _previouslyOnlineIds,
              );
              for (final id in newArrivals) {
                final arrived = faculty.firstWhere((f) => f.user.id == id);
                _arrivalController.add(arrived);
                debugPrint(
                  '[FacultyProvider] \u{1F7E2} Faculty arrived: ${arrived.user.fullName}',
                );
              }
            }
            _previouslyOnlineIds
              ..clear()
              ..addAll(currentOnlineIds);
            _hasReceivedFirstSnapshot = true;

            _applyFilters();
            _isLoading = false;
            _error = null;
            _retryCount = 0;
            _retryTimer?.cancel();
            notifyListeners();
          },
          onError: (e) {
            _error = e.toString();
            _isLoading = false;
            notifyListeners();
          },
        );

    // Also reload departments
    await _loadDepartments();
  }

  @override
  void dispose() {
    _facultySubscription?.cancel();
    _refreshTimer?.cancel();
    _retryTimer?.cancel();
    _arrivalController.close();
    super.dispose();
  }
}
