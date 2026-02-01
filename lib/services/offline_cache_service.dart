import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/location_model.dart';

/// Service for offline caching of faculty data and locations
class OfflineCacheService {
  static Database? _database;
  static final OfflineCacheService _instance = OfflineCacheService._internal();
  
  factory OfflineCacheService() => _instance;
  OfflineCacheService._internal();
  
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  final _connectivityController = StreamController<bool>.broadcast();
  
  bool _isOnline = true;
  bool get isOnline => _isOnline;
  Stream<bool> get connectivityStream => _connectivityController.stream;
  
  /// Initialize the database
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
  
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'unitrack_cache.db');
    
    return await openDatabase(
      path,
      version: 2,
      onCreate: _createTables,
      onUpgrade: _upgradeTables,
    );
  }
  
  Future<void> _createTables(Database db, int version) async {
    // Faculty/Staff cache table
    await db.execute('''
      CREATE TABLE faculty_cache (
        id TEXT PRIMARY KEY,
        email TEXT,
        first_name TEXT,
        last_name TEXT,
        role TEXT,
        department TEXT,
        position TEXT,
        photo_url TEXT,
        phone_number TEXT,
        campus_id TEXT,
        availability_status TEXT,
        custom_status_message TEXT,
        is_tracking_enabled INTEGER,
        cached_at INTEGER
      )
    ''');
    
    // Location cache table
    await db.execute('''
      CREATE TABLE location_cache (
        user_id TEXT PRIMARY KEY,
        latitude REAL,
        longitude REAL,
        accuracy REAL,
        status TEXT,
        quick_message TEXT,
        is_within_campus INTEGER,
        is_moving INTEGER,
        is_manual_pin INTEGER,
        timestamp INTEGER,
        cached_at INTEGER
      )
    ''');
    
    // Last sync timestamp
    await db.execute('''
      CREATE TABLE sync_meta (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
  }
  
  Future<void> _upgradeTables(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add availability status columns
      await db.execute('ALTER TABLE faculty_cache ADD COLUMN availability_status TEXT');
      await db.execute('ALTER TABLE faculty_cache ADD COLUMN custom_status_message TEXT');
    }
  }
  
  /// Initialize connectivity monitoring
  Future<void> initialize() async {
    // Check initial connectivity
    final results = await _connectivity.checkConnectivity();
    _isOnline = !results.contains(ConnectivityResult.none);
    _connectivityController.add(_isOnline);
    
    // Listen for changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      final wasOnline = _isOnline;
      _isOnline = !results.contains(ConnectivityResult.none);
      
      if (wasOnline != _isOnline) {
        _connectivityController.add(_isOnline);
        debugPrint('📶 Connectivity changed: ${_isOnline ? "Online" : "Offline"}');
      }
    });
  }
  
  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivityController.close();
  }
  
  // ==================== FACULTY CACHE ====================
  
  /// Cache a list of faculty members
  Future<void> cacheFacultyList(List<UserModel> faculty) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    
    for (final user in faculty) {
      batch.insert(
        'faculty_cache',
        {
          'id': user.id,
          'email': user.email,
          'first_name': user.firstName,
          'last_name': user.lastName,
          'role': user.role.name,
          'department': user.department,
          'position': user.position,
          'photo_url': user.photoUrl,
          'phone_number': user.phoneNumber,
          'campus_id': user.campusId,
          'availability_status': user.availabilityStatus?.name,
          'custom_status_message': user.customStatusMessage,
          'is_tracking_enabled': user.isTrackingEnabled == true ? 1 : 0,
          'cached_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit(noResult: true);
    await _updateSyncMeta('faculty_last_sync', now.toString());
    debugPrint('💾 Cached ${faculty.length} faculty members');
  }
  
  /// Get cached faculty list
  Future<List<UserModel>> getCachedFaculty() async {
    final db = await database;
    final results = await db.query('faculty_cache', orderBy: 'last_name ASC');
    
    return results.map((row) => _userFromRow(row)).toList();
  }
  
  /// Search cached faculty
  Future<List<UserModel>> searchCachedFaculty(String query) async {
    final db = await database;
    final queryLower = '%${query.toLowerCase()}%';
    
    final results = await db.query(
      'faculty_cache',
      where: 'LOWER(first_name) LIKE ? OR LOWER(last_name) LIKE ? OR LOWER(department) LIKE ?',
      whereArgs: [queryLower, queryLower, queryLower],
      orderBy: 'last_name ASC',
    );
    
    return results.map((row) => _userFromRow(row)).toList();
  }
  
  UserModel _userFromRow(Map<String, dynamic> row) {
    return UserModel(
      id: row['id'] as String,
      email: row['email'] as String? ?? '',
      firstName: row['first_name'] as String? ?? '',
      lastName: row['last_name'] as String? ?? '',
      role: _parseRole(row['role'] as String?),
      department: row['department'] as String?,
      position: row['position'] as String?,
      photoUrl: row['photo_url'] as String?,
      phoneNumber: row['phone_number'] as String?,
      campusId: row['campus_id'] as String? ?? 'isulan',
      availabilityStatus: _parseAvailabilityStatus(row['availability_status'] as String?),
      customStatusMessage: row['custom_status_message'] as String?,
      isTrackingEnabled: (row['is_tracking_enabled'] as int?) == 1,
      createdAt: DateTime.now(),
    );
  }
  
  UserRole _parseRole(String? role) {
    switch (role) {
      case 'admin': return UserRole.admin;
      case 'staff': return UserRole.staff;
      default: return UserRole.student;
    }
  }
  
  AvailabilityStatus? _parseAvailabilityStatus(String? status) {
    if (status == null) return null;
    return AvailabilityStatus.values.firstWhere(
      (e) => e.name == status,
      orElse: () => AvailabilityStatus.available,
    );
  }
  
  // ==================== LOCATION CACHE ====================
  
  /// Cache location for a user
  Future<void> cacheLocation(String userId, LocationModel location) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    await db.insert(
      'location_cache',
      {
        'user_id': userId,
        'latitude': location.latitude,
        'longitude': location.longitude,
        'accuracy': location.accuracy,
        'status': location.status,
        'quick_message': location.quickMessage,
        'is_within_campus': location.isWithinCampus ? 1 : 0,
        'is_moving': location.isMoving ? 1 : 0,
        'is_manual_pin': location.isManualPin ? 1 : 0,
        'timestamp': location.timestamp.millisecondsSinceEpoch,
        'cached_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  /// Cache multiple locations
  Future<void> cacheLocations(Map<String, LocationModel> locations) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    
    for (final entry in locations.entries) {
      final location = entry.value;
      batch.insert(
        'location_cache',
        {
          'user_id': entry.key,
          'latitude': location.latitude,
          'longitude': location.longitude,
          'accuracy': location.accuracy,
          'status': location.status,
          'quick_message': location.quickMessage,
          'is_within_campus': location.isWithinCampus ? 1 : 0,
          'is_moving': location.isMoving ? 1 : 0,
          'is_manual_pin': location.isManualPin ? 1 : 0,
          'timestamp': location.timestamp.millisecondsSinceEpoch,
          'cached_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit(noResult: true);
    debugPrint('💾 Cached ${locations.length} locations');
  }
  
  /// Get cached location for a user
  Future<LocationModel?> getCachedLocation(String userId) async {
    final db = await database;
    final results = await db.query(
      'location_cache',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    
    if (results.isEmpty) return null;
    return _locationFromRow(results.first);
  }
  
  /// Get all cached locations
  Future<Map<String, LocationModel>> getAllCachedLocations() async {
    final db = await database;
    final results = await db.query('location_cache');
    
    final Map<String, LocationModel> locations = {};
    for (final row in results) {
      locations[row['user_id'] as String] = _locationFromRow(row);
    }
    return locations;
  }
  
  LocationModel _locationFromRow(Map<String, dynamic> row) {
    return LocationModel(
      userId: row['user_id'] as String,
      latitude: row['latitude'] as double,
      longitude: row['longitude'] as double,
      accuracy: row['accuracy'] as double?,
      status: row['status'] as String?,
      quickMessage: row['quick_message'] as String?,
      isWithinCampus: (row['is_within_campus'] as int?) == 1,
      isMoving: (row['is_moving'] as int?) == 1,
      isManualPin: (row['is_manual_pin'] as int?) == 1,
      timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
    );
  }
  
  // ==================== SYNC METADATA ====================
  
  Future<void> _updateSyncMeta(String key, String value) async {
    final db = await database;
    await db.insert(
      'sync_meta',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  Future<String?> getSyncMeta(String key) async {
    final db = await database;
    final results = await db.query(
      'sync_meta',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    
    if (results.isEmpty) return null;
    return results.first['value'] as String?;
  }
  
  /// Get last sync time for faculty
  Future<DateTime?> getLastFacultySync() async {
    final value = await getSyncMeta('faculty_last_sync');
    if (value == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(int.parse(value));
  }
  
  /// Clear all cached data
  Future<void> clearCache() async {
    final db = await database;
    await db.delete('faculty_cache');
    await db.delete('location_cache');
    await db.delete('sync_meta');
    debugPrint('🗑️ Cache cleared');
  }
}
