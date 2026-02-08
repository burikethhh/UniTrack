import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/location_model.dart';

/// Service for offline caching of faculty data and locations
/// On web: uses SharedPreferences + in-memory cache
/// On mobile: uses SQLite database
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
  
  // Web in-memory cache
  List<UserModel>? _webFacultyCache;
  Map<String, LocationModel>? _webLocationCache;
  
  /// Initialize the database (or connectivity monitoring on web)
  Future<Database> get database async {
    if (kIsWeb) throw UnsupportedError('SQLite not available on web — use web-specific methods');
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
  
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'unitrack_cache.db');
    
    return await openDatabase(
      path,
      version: 3,
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
    
    // Pending offline write operations
    await db.execute('''
      CREATE TABLE pending_operations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        collection TEXT NOT NULL,
        doc_id TEXT,
        operation TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        retries INTEGER DEFAULT 0
      )
    ''');
  }
  
  Future<void> _upgradeTables(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add availability status columns
      await db.execute('ALTER TABLE faculty_cache ADD COLUMN availability_status TEXT');
      await db.execute('ALTER TABLE faculty_cache ADD COLUMN custom_status_message TEXT');
    }
    if (oldVersion < 3) {
      // Add pending operations table for offline write queue
      await db.execute('''
        CREATE TABLE IF NOT EXISTS pending_operations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          collection TEXT NOT NULL,
          doc_id TEXT,
          operation TEXT NOT NULL,
          data TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          retries INTEGER DEFAULT 0
        )
      ''');
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
        
        // Auto-sync pending operations when coming back online
        if (_isOnline && !wasOnline) {
          syncPendingOperations();
        }
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
    if (kIsWeb) {
      _webFacultyCache = List.from(faculty);
      // Persist to SharedPreferences as JSON
      try {
        final prefs = await SharedPreferences.getInstance();
        final jsonList = faculty.map((u) => _userToJson(u)).toList();
        await prefs.setString('faculty_cache', jsonEncode(jsonList));
      } catch (e) {
        debugPrint('⚠️ Web cache save error: $e');
      }
      debugPrint('💾 Web-cached ${faculty.length} faculty members');
      return;
    }
    
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
    if (kIsWeb) {
      if (_webFacultyCache != null) return _webFacultyCache!;
      // Try loading from SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        final jsonStr = prefs.getString('faculty_cache');
        if (jsonStr != null) {
          final jsonList = jsonDecode(jsonStr) as List;
          _webFacultyCache = jsonList.map((j) => _userFromJson(j as Map<String, dynamic>)).toList();
          return _webFacultyCache!;
        }
      } catch (e) {
        debugPrint('⚠️ Web cache load error: $e');
      }
      return [];
    }
    
    final db = await database;
    final results = await db.query('faculty_cache', orderBy: 'last_name ASC');
    
    return results.map((row) => _userFromRow(row)).toList();
  }
  
  /// Search cached faculty
  Future<List<UserModel>> searchCachedFaculty(String query) async {
    if (kIsWeb) {
      final allFaculty = await getCachedFaculty();
      final q = query.toLowerCase();
      return allFaculty.where((u) =>
        u.firstName.toLowerCase().contains(q) ||
        u.lastName.toLowerCase().contains(q) ||
        (u.department?.toLowerCase().contains(q) ?? false)
      ).toList();
    }
    
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
    if (kIsWeb) {
      _webLocationCache ??= {};
      _webLocationCache![userId] = location;
      return;
    }
    
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
    if (kIsWeb) {
      _webLocationCache ??= {};
      _webLocationCache!.addAll(locations);
      debugPrint('💾 Web-cached ${locations.length} locations');
      return;
    }
    
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
    if (kIsWeb) {
      return _webLocationCache?[userId];
    }
    
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
    if (kIsWeb) {
      return _webLocationCache ?? {};
    }
    
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
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final value = prefs.getString('faculty_last_sync');
        if (value != null) return DateTime.fromMillisecondsSinceEpoch(int.parse(value));
      } catch (_) {}
      return null;
    }
    
    final value = await getSyncMeta('faculty_last_sync');
    if (value == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(int.parse(value));
  }
  
  // ==================== WEB JSON HELPERS ====================
  
  /// Convert UserModel to JSON map for web caching
  Map<String, dynamic> _userToJson(UserModel user) {
    return {
      'id': user.id,
      'email': user.email,
      'firstName': user.firstName,
      'lastName': user.lastName,
      'role': user.role.name,
      'department': user.department,
      'position': user.position,
      'photoUrl': user.photoUrl,
      'phoneNumber': user.phoneNumber,
      'campusId': user.campusId,
      'availabilityStatus': user.availabilityStatus?.name,
      'customStatusMessage': user.customStatusMessage,
      'isTrackingEnabled': user.isTrackingEnabled,
    };
  }
  
  /// Create UserModel from JSON map for web cache
  UserModel _userFromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      role: _parseRole(json['role'] as String?),
      department: json['department'] as String?,
      position: json['position'] as String?,
      photoUrl: json['photoUrl'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      campusId: json['campusId'] as String? ?? 'isulan',
      availabilityStatus: _parseAvailabilityStatus(json['availabilityStatus'] as String?),
      customStatusMessage: json['customStatusMessage'] as String?,
      isTrackingEnabled: json['isTrackingEnabled'] as bool? ?? false,
      createdAt: DateTime.now(),
    );
  }
  
  /// Clear all cached data
  Future<void> clearCache() async {
    if (kIsWeb) {
      _webFacultyCache = null;
      _webLocationCache = null;
      _webPendingOps.clear();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('faculty_cache');
        await prefs.remove('pending_operations');
      } catch (_) {}
      debugPrint('🗑️ Web cache cleared');
      return;
    }
    
    final db = await database;
    await db.delete('faculty_cache');
    await db.delete('location_cache');
    await db.delete('sync_meta');
    await db.delete('pending_operations');
    debugPrint('🗑️ Cache cleared');
  }

  // ==================== OFFLINE WRITE QUEUE ====================

  // Web in-memory pending operations
  final List<Map<String, dynamic>> _webPendingOps = [];
  
  /// Queue a Firestore write operation for later sync
  /// [collection] — Firestore collection name
  /// [docId] — Document ID (null for auto-generated)
  /// [operation] — 'set', 'update', or 'delete'
  /// [data] — The data map to write
  Future<void> queueOperation({
    required String collection,
    String? docId,
    required String operation,
    required Map<String, dynamic> data,
  }) async {
    // If online, execute immediately
    if (_isOnline) {
      try {
        await _executeFirestoreOp(collection, docId, operation, data);
        debugPrint('✅ Executed operation immediately: $operation on $collection/$docId');
        return;
      } catch (e) {
        debugPrint('⚠️ Immediate write failed, queuing: $e');
      }
    }
    
    final entry = {
      'collection': collection,
      'doc_id': docId,
      'operation': operation,
      'data': jsonEncode(data),
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'retries': 0,
    };

    if (kIsWeb) {
      _webPendingOps.add(entry);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pending_operations', jsonEncode(_webPendingOps));
      } catch (_) {}
      debugPrint('📝 Queued operation (web): $operation on $collection/$docId');
      return;
    }
    
    final db = await database;
    await db.insert('pending_operations', entry);
    debugPrint('📝 Queued operation: $operation on $collection/$docId');
  }
  
  /// Get count of pending operations
  Future<int> getPendingCount() async {
    if (kIsWeb) return _webPendingOps.length;
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM pending_operations');
    return Sqflite.firstIntValue(result) ?? 0;
  }
  
  /// Sync all pending operations to Firestore
  Future<int> syncPendingOperations() async {
    if (!_isOnline) return 0;
    
    int synced = 0;
    
    if (kIsWeb) {
      final ops = List<Map<String, dynamic>>.from(_webPendingOps);
      for (final op in ops) {
        try {
          final data = jsonDecode(op['data'] as String) as Map<String, dynamic>;
          await _executeFirestoreOp(
            op['collection'] as String,
            op['doc_id'] as String?,
            op['operation'] as String,
            data,
          );
          _webPendingOps.remove(op);
          synced++;
        } catch (e) {
          debugPrint('⚠️ Sync failed for operation: $e');
          op['retries'] = (op['retries'] as int? ?? 0) + 1;
          // Remove after 5 retries
          if ((op['retries'] as int) >= 5) {
            _webPendingOps.remove(op);
          }
        }
      }
      // Persist remaining
      try {
        final prefs = await SharedPreferences.getInstance();
        if (_webPendingOps.isEmpty) {
          await prefs.remove('pending_operations');
        } else {
          await prefs.setString('pending_operations', jsonEncode(_webPendingOps));
        }
      } catch (_) {}
      debugPrint('🔄 Web sync complete: $synced operations synced');
      return synced;
    }
    
    final db = await database;
    final ops = await db.query('pending_operations', orderBy: 'created_at ASC');
    
    for (final op in ops) {
      try {
        final data = jsonDecode(op['data'] as String) as Map<String, dynamic>;
        await _executeFirestoreOp(
          op['collection'] as String,
          op['doc_id'] as String?,
          op['operation'] as String,
          data,
        );
        await db.delete('pending_operations', where: 'id = ?', whereArgs: [op['id']]);
        synced++;
      } catch (e) {
        debugPrint('⚠️ Sync failed for op ${op['id']}: $e');
        final retries = (op['retries'] as int? ?? 0) + 1;
        if (retries >= 5) {
          await db.delete('pending_operations', where: 'id = ?', whereArgs: [op['id']]);
          debugPrint('🗑️ Dropped op ${op['id']} after 5 retries');
        } else {
          await db.update(
            'pending_operations',
            {'retries': retries},
            where: 'id = ?',
            whereArgs: [op['id']],
          );
        }
      }
    }
    
    debugPrint('🔄 Sync complete: $synced/${ops.length} operations synced');
    return synced;
  }
  
  /// Execute a single Firestore operation
  Future<void> _executeFirestoreOp(
    String collection,
    String? docId,
    String operation,
    Map<String, dynamic> data,
  ) async {
    final firestore = FirebaseFirestore.instance;
    
    switch (operation) {
      case 'set':
        if (docId != null) {
          await firestore.collection(collection).doc(docId).set(data, SetOptions(merge: true));
        } else {
          await firestore.collection(collection).add(data);
        }
        break;
      case 'update':
        if (docId == null) throw 'Cannot update without a document ID';
        await firestore.collection(collection).doc(docId).update(data);
        break;
      case 'delete':
        if (docId == null) throw 'Cannot delete without a document ID';
        await firestore.collection(collection).doc(docId).delete();
        break;
      default:
        throw 'Unknown operation: $operation';
    }
  }
}
