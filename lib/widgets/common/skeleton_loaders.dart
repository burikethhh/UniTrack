import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Reusable shimmer skeleton loading widgets
/// Replace boring spinners with elegant skeleton animations

/// Base shimmer container for skeleton loading
class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Circular shimmer placeholder (for avatars)
class ShimmerCircle extends StatelessWidget {
  final double size;

  const ShimmerCircle({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Shimmer wrapper that applies the shimmer effect to children
class ShimmerWrapper extends StatelessWidget {
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;

  const ShimmerWrapper({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: baseColor ?? Colors.grey[300]!,
      highlightColor: highlightColor ?? Colors.grey[100]!,
      child: child,
    );
  }
}

/// Skeleton loading for faculty card
class FacultyCardSkeleton extends StatelessWidget {
  const FacultyCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrapper(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar skeleton
            const ShimmerCircle(size: 56),
            const SizedBox(width: 16),

            // Text content skeleton
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  ShimmerBox(
                    width: MediaQuery.of(context).size.width * 0.4,
                    height: 18,
                  ),
                  const SizedBox(height: 8),
                  // Department
                  ShimmerBox(
                    width: MediaQuery.of(context).size.width * 0.3,
                    height: 14,
                    borderRadius: 4,
                  ),
                  const SizedBox(height: 6),
                  // Status
                  const ShimmerBox(width: 80, height: 24, borderRadius: 12),
                ],
              ),
            ),

            // Action icon
            const ShimmerCircle(size: 32),
          ],
        ),
      ),
    );
  }
}

/// Skeleton loading for a list of faculty cards
class FacultyListSkeleton extends StatelessWidget {
  final int itemCount;

  const FacultyListSkeleton({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      itemBuilder: (context, index) => const FacultyCardSkeleton(),
    );
  }
}

/// Skeleton loading for notification item
class NotificationItemSkeleton extends StatelessWidget {
  const NotificationItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrapper(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ShimmerCircle(size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(
                    width: MediaQuery.of(context).size.width * 0.5,
                    height: 16,
                  ),
                  const SizedBox(height: 6),
                  ShimmerBox(
                    width: MediaQuery.of(context).size.width * 0.7,
                    height: 14,
                  ),
                  const SizedBox(height: 8),
                  const ShimmerBox(width: 80, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton loading for notification list
class NotificationListSkeleton extends StatelessWidget {
  final int itemCount;

  const NotificationListSkeleton({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      itemBuilder: (context, index) => const NotificationItemSkeleton(),
    );
  }
}


