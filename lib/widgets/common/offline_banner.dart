import 'package:flutter/material.dart';
import '../../services/offline_cache_service.dart';

/// A banner that shows when the app is offline
class OfflineModeBanner extends StatelessWidget {
  final Widget child;

  const OfflineModeBanner({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: OfflineCacheService().connectivityStream,
      initialData: OfflineCacheService().isOnline,
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? true;

        return Column(
          children: [
            // Offline banner
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: isOnline ? 0 : 48,
              child: Material(
                color: Colors.orange[700],
                child: SafeArea(
                  bottom: false,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.cloud_off,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'You\'re offline - Showing cached data',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Main content
            Expanded(child: child),
          ],
        );
      },
    );
  }
}

/// Connectivity-aware wrapper that shows a banner and handles offline state
class ConnectivityAwareWidget extends StatefulWidget {
  final Widget child;
  final Widget? offlineWidget;
  final bool showBanner;

  const ConnectivityAwareWidget({
    super.key,
    required this.child,
    this.offlineWidget,
    this.showBanner = true,
  });

  @override
  State<ConnectivityAwareWidget> createState() => _ConnectivityAwareWidgetState();
}

class _ConnectivityAwareWidgetState extends State<ConnectivityAwareWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: OfflineCacheService().connectivityStream,
      initialData: OfflineCacheService().isOnline,
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? true;

        if (!isOnline) {
          _animationController.forward();
        } else {
          _animationController.reverse();
        }

        return Stack(
          children: [
            widget.child,
            // Offline indicator
            if (widget.showBanner)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _animation,
                  child: Container(
                    color: Colors.orange[700],
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 8,
                      bottom: 8,
                      left: 16,
                      right: 16,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.wifi_off,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Flexible(
                          child: Text(
                            'No internet connection - Using cached data',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Small connectivity indicator dot
class ConnectivityIndicator extends StatelessWidget {
  final double size;

  const ConnectivityIndicator({
    super.key,
    this.size = 12,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: OfflineCacheService().connectivityStream,
      initialData: OfflineCacheService().isOnline,
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? true;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isOnline ? Colors.green : Colors.orange,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (isOnline ? Colors.green : Colors.orange).withOpacity(0.4),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: isOnline
              ? null
              : Icon(
                  Icons.cloud_off,
                  size: size * 0.7,
                  color: Colors.white,
                ),
        );
      },
    );
  }
}

/// Sync status indicator showing last sync time
class SyncStatusIndicator extends StatelessWidget {
  final DateTime? lastSyncTime;
  
  const SyncStatusIndicator({
    super.key,
    this.lastSyncTime,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: OfflineCacheService().connectivityStream,
      initialData: OfflineCacheService().isOnline,
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? true;
        final syncText = _getSyncText();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isOnline ? Colors.green[50] : Colors.orange[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isOnline ? Colors.green[200]! : Colors.orange[200]!,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isOnline ? Icons.cloud_done : Icons.cloud_off,
                size: 16,
                color: isOnline ? Colors.green[700] : Colors.orange[700],
              ),
              const SizedBox(width: 6),
              Text(
                syncText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isOnline ? Colors.green[700] : Colors.orange[700],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getSyncText() {
    if (lastSyncTime == null) return 'Not synced';

    final now = DateTime.now();
    final diff = now.difference(lastSyncTime!);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
