import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

/// Service to monitor network connectivity
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final _connectivityController = StreamController<bool>.broadcast();
  Stream<bool> get connectivityStream => _connectivityController.stream;
  
  bool _isConnected = true;
  bool get isConnected => _isConnected;
  
  Timer? _checkTimer;
  
  /// Start monitoring connectivity
  void startMonitoring() {
    _checkConnectivity();
    // Check connectivity every 10 seconds
    _checkTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkConnectivity();
    });
  }
  
  /// Stop monitoring
  void stopMonitoring() {
    _checkTimer?.cancel();
    _checkTimer = null;
  }
  
  /// Check current connectivity
  Future<bool> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      final connected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      
      if (_isConnected != connected) {
        _isConnected = connected;
        _connectivityController.add(connected);
      }
      return connected;
    } on SocketException catch (_) {
      if (_isConnected) {
        _isConnected = false;
        _connectivityController.add(false);
      }
      return false;
    } on TimeoutException catch (_) {
      if (_isConnected) {
        _isConnected = false;
        _connectivityController.add(false);
      }
      return false;
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
