import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service to monitor network connectivity — single source of truth.
/// Both the auth/login screens and [OfflineCacheService] subscribe to this.
/// Works on both mobile (dart:io) and web (connectivity_plus).
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final _connectivityController = StreamController<bool>.broadcast();
  Stream<bool> get connectivityStream => _connectivityController.stream;

  bool _isConnected = true;
  bool get isConnected => _isConnected;

  Timer? _checkTimer;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Start monitoring connectivity (idempotent — safe to call from
  /// multiple subscribers).
  void startMonitoring() {
    _checkConnectivity();

    // Use connectivity_plus for real-time monitoring (supports web)
    _connectivitySubscription ??= _connectivity.onConnectivityChanged.listen((
      results,
    ) {
      final connected = !results.contains(ConnectivityResult.none);
      if (_isConnected != connected) {
        _isConnected = connected;
        _connectivityController.add(connected);
        if (kDebugMode) {
          debugPrint(
          '📶 Connectivity changed: ${connected ? "Online" : "Offline"}',
        );
        }
      }
    });

    // Periodic check as backup
    _checkTimer ??= Timer.periodic(const Duration(seconds: 30), (_) {
      _checkConnectivity();
    });
  }

  /// Stop monitoring
  void stopMonitoring() {
    _checkTimer?.cancel();
    _checkTimer = null;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  /// Check current connectivity using connectivity_plus (works on web)
  Future<bool> _checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final connected = !results.contains(ConnectivityResult.none);

      if (_isConnected != connected) {
        _isConnected = connected;
        _connectivityController.add(connected);
      }
      return connected;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Connectivity check error: $e');
      // Emit the failure on the stream so subscribers learn the check
      // didn't succeed — previously silently returned stale state.
      _connectivityController.add(_isConnected);
      return _isConnected;
    }
  }

  /// Force check connectivity now
  Future<bool> checkNow() => _checkConnectivity();

  void dispose() {
    stopMonitoring();
    _connectivityController.close();
  }
}

/// Mixin to add connectivity awareness to widgets — listens to the
/// [ConnectivityService] singleton so there's only ever one source of truth.
mixin ConnectivityAware<T extends StatefulWidget> on State<T> {
  StreamSubscription<bool>? _connectivitySubscription;
  bool _isOnline = true;

  bool get isOnline => _isOnline;

  @override
  void initState() {
    super.initState();
    _isOnline = ConnectivityService().isConnected;
    _connectivitySubscription = ConnectivityService().connectivityStream.listen(
      (connected) {
        if (mounted) {
          setState(() => _isOnline = connected);
          onConnectivityChanged(connected);
        }
      },
    );
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  /// Override to handle connectivity changes
  void onConnectivityChanged(bool isConnected) {}
}
