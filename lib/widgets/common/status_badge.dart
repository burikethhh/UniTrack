import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Status indicator badge
class StatusBadge extends StatelessWidget {
  final String status;
  final bool showDot;
  final double? fontSize;
  
  const StatusBadge({
    super.key,
    required this.status,
    this.showDot = true,
    this.fontSize,
  });
  
  @override
  Widget build(BuildContext context) {
    final color = AppColors.getStatusColor(status);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: fontSize ?? 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Online/Offline indicator
class OnlineIndicator extends StatelessWidget {
  final bool isOnline;
  final double size;
  
  const OnlineIndicator({
    super.key,
    required this.isOnline,
    this.size = 12,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isOnline ? AppColors.statusAvailable : AppColors.statusUnavailable,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: (isOnline ? AppColors.statusAvailable : AppColors.statusUnavailable)
                .withValues(alpha: 0.4),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

/// Pulsing online indicator (animated)
class PulsingOnlineIndicator extends StatefulWidget {
  final bool isOnline;
  final double size;
  
  const PulsingOnlineIndicator({
    super.key,
    required this.isOnline,
    this.size = 12,
  });
  
  @override
  State<PulsingOnlineIndicator> createState() => _PulsingOnlineIndicatorState();
}

class _PulsingOnlineIndicatorState extends State<PulsingOnlineIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    
    if (widget.isOnline) {
      _controller.repeat(reverse: true);
    }
  }
  
  @override
  void didUpdateWidget(PulsingOnlineIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOnline && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isOnline && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    if (!widget.isOnline) {
      return OnlineIndicator(isOnline: false, size: widget.size);
    }
    
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: OnlineIndicator(isOnline: true, size: widget.size),
        );
      },
    );
  }
}
