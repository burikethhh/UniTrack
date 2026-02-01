import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/database_service.dart';

/// Faculty Provider for student module
class FacultyProvider extends ChangeNotifier {
  final DatabaseService _databaseService;
  
  FacultyProvider({
    required DatabaseService databaseService,
  }) : _databaseService = databaseService;
  
  List<FacultyWithLocation> _allFaculty = [];
  List<FacultyWithLocation> _filteredFaculty = [];
  List<DepartmentModel> _departments = [];
  String _searchQuery = '';
  String? _selectedDepartment;
  bool _showOnlineOnly = false;
  bool _isLoading = false;
  String? _error;
  
  // Campus filter - shows faculty from specific campus
  String? _campusFilter;
  
  // Focused faculty - when searching, only show this faculty on map
  String? _focusedFacultyId;
  
  StreamSubscription? _facultySubscription;
  Timer? _refreshTimer;
  
  // Getters
  List<FacultyWithLocation> get allFaculty => _allFaculty;
  List<FacultyWithLocation> get filteredFaculty => _filteredFaculty;
  List<DepartmentModel> get departments => _departments;
  String get searchQuery => _searchQuery;
  String? get selectedDepartment => _selectedDepartment;
  bool get showOnlineOnly => _showOnlineOnly;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get campusFilter => _campusFilter;
  String? get focusedFacultyId => _focusedFacultyId;
  
  int get totalFaculty => _allFaculty.length;
  int get onlineFaculty => _allFaculty.where((f) => f.isOnline).length;
  
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
  
  /// Initialize and start listening
  void initialize() {
    _isLoading = true;
    notifyListeners();
    
    // Listen to faculty updates with real-time changes
    _facultySubscription = _databaseService
        .getFacultyWithLocationsStream()
        .listen((faculty) {
      _allFaculty = faculty;
      _applyFilters();
      _isLoading = false;
      _error = null;
      notifyListeners();
    }, onError: (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    });
    
    // Start periodic refresh timer to re-evaluate staleness (every 5 seconds for more responsive updates)
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      // Re-apply filters to update isOnline based on timestamp staleness
      _applyFilters();
      notifyListeners();
    });
    
    // Load departments
    _loadDepartments();
  }
  
  /// Load departments
  Future<void> _loadDepartments() async {
    _departments = await _databaseService.getAllDepartments();
    notifyListeners();
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
  
  /// Toggle online only filter
  void toggleOnlineOnly() {
    _showOnlineOnly = !_showOnlineOnly;
    _applyFilters();
    notifyListeners();
  }
  
  /// Clear all filters
  void clearFilters() {
    _searchQuery = '';
    _selectedDepartment = null;
    _showOnlineOnly = false;
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
        final matchesDept = faculty.user.department?.toLowerCase().contains(query) ?? false;
        final matchesPosition = faculty.user.position?.toLowerCase().contains(query) ?? false;
        
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
      
      // Online filter
      if (_showOnlineOnly && !faculty.isOnline) {
        return false;
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
  
  /// Refresh data
  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    _isLoading = false;
    notifyListeners();
  }
  
  @override
  void dispose() {
    _facultySubscription?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }
}
