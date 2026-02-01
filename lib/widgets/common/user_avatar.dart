import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// User avatar with initials or image
class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String initials;
  final double size;
  final Color? backgroundColor;
  final bool showBorder;
  final Widget? badge;
  
  const UserAvatar({
    super.key,
    this.imageUrl,
    required this.initials,
    this.size = 48,
    this.backgroundColor,
    this.showBorder = false,
    this.badge,
  });
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: backgroundColor ?? AppColors.primary,
            border: showBorder
                ? Border.all(color: Colors.white, width: 3)
                : null,
            boxShadow: showBorder
                ? [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: imageUrl != null && imageUrl!.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildInitials(),
                    loadingBuilder: (_, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return _buildInitials();
                    },
                  ),
                )
              : _buildInitials(),
        ),
        if (badge != null)
          Positioned(
            right: 0,
            bottom: 0,
            child: badge!,
          ),
      ],
    );
  }
  
  Widget _buildInitials() {
    return Center(
      child: Text(
        initials.toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.4,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Faculty avatar with online status
class FacultyAvatar extends StatelessWidget {
  final String? imageUrl;
  final String initials;
  final bool isOnline;
  final double size;
  
  const FacultyAvatar({
    super.key,
    this.imageUrl,
    required this.initials,
    required this.isOnline,
    this.size = 48,
  });
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        UserAvatar(
          imageUrl: imageUrl,
          initials: initials,
          size: size,
          backgroundColor: isOnline ? AppColors.accent : AppColors.textSecondary,
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: size * 0.3,
            height: size * 0.3,
            decoration: BoxDecoration(
              color: isOnline ? AppColors.statusAvailable : AppColors.statusUnavailable,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
