import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service to monitor network connectivity
/// Works on both mobile (dart:io) and web (connectivity_plus)
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
  
  /// Start monitoring connectivity (works on both web and mobile)
  void startMonitoring() {
    _checkConnectivity();
    
    // Use connectivity_plus for real-time monitoring (supports web)
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      final connected = !results.contains(ConnectivityResult.none);
      if (_isConnected != connected) {
        _isConnected = connected;
        _connectivityController.add(connected);
        debugPrint('📶 Connectivity changed: ${connected ? "Online" : "Offline"}');
      }
    });
    
    // Periodic check as backup
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (_) {
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
      debugPrint('⚠️ Connectivity check error: $e');
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

/// Widget to show offline banner
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: ConnectivityService().connectivityStream,
      initialData: ConnectivityService().isConnected,
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? true;
        
        if (isOnline) return const SizedBox.shrink();
        
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          color: Colors.red.shade700,
          child: const SafeArea(
            bottom: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text(
                  'No internet connection',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Mixin to add connectivity awareness to widgets
mixin ConnectivityAware<T extends StatefulWidget> on State<T> {
  StreamSubscription<bool>? _connectivitySubscription;
  bool _isOnline = true;
  
  bool get isOnline => _isOnline;
  
  @override
  void initState() {
    super.initState();
    _isOnline = ConnectivityService().isConnected;
    _connectivitySubscription = ConnectivityService()
        .connectivityStream
        .listen((connected) {
      if (mounted) {
        setState(() => _isOnline = connected);
        onConnectivityChanged(connected);
      }
    });
  }
  
  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
  
  /// Override to handle connectivity changes
  void onConnectivityChanged(bool isConnected) {}
}
