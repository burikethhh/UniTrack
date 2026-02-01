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

  const ShimmerCircle({
    super.key,
    required this.size,
  });

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
              color: Colors.black.withOpacity(0.05),
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
                  const ShimmerBox(
                    width: 80,
                    height: 24,
                    borderRadius: 12,
                  ),
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

  const FacultyListSkeleton({
    super.key,
    this.itemCount = 5,
  });

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

/// Skeleton loading for map card
class MapCardSkeleton extends StatelessWidget {
  const MapCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrapper(
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Map placeholder
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ShimmerBox(width: 150, height: 20),
                  const SizedBox(height: 8),
                  ShimmerBox(
                    width: MediaQuery.of(context).size.width * 0.6,
                    height: 14,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton loading for profile header
class ProfileHeaderSkeleton extends StatelessWidget {
  const ProfileHeaderSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrapper(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.grey[300]!,
              Colors.grey[200]!,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Avatar
              const ShimmerCircle(size: 100),
              const SizedBox(height: 16),
              // Name
              const ShimmerBox(width: 180, height: 24),
              const SizedBox(height: 8),
              // Email
              const ShimmerBox(width: 220, height: 16),
              const SizedBox(height: 16),
              // Stats row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  3,
                  (index) => Column(
                    children: const [
                      ShimmerBox(width: 40, height: 28),
                      SizedBox(height: 4),
                      ShimmerBox(width: 60, height: 14),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
              color: Colors.black.withOpacity(0.04),
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

  const NotificationListSkeleton({
    super.key,
    this.itemCount = 6,
  });

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

/// Skeleton for search results page
class SearchResultsSkeleton extends StatelessWidget {
  const SearchResultsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerBox(width: 120, height: 14),
                SizedBox(height: 16),
              ],
            ),
          ),
          // Results list
          const FacultyListSkeleton(itemCount: 4),
        ],
      ),
    );
  }
}

/// Skeleton for campus selector
class CampusSelectorSkeleton extends StatelessWidget {
  const CampusSelectorSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrapper(
      child: SizedBox(
        height: 120,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 3,
          itemBuilder: (context, index) => Container(
            width: 160,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton for dashboard stats
class DashboardStatsSkeleton extends StatelessWidget {
  const DashboardStatsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrapper(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: List.generate(
            3,
            (index) => Expanded(
              child: Container(
                margin: EdgeInsets.only(right: index < 2 ? 12 : 0),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: const [
                    ShimmerCircle(size: 48),
                    SizedBox(height: 12),
                    ShimmerBox(width: 50, height: 24),
                    SizedBox(height: 6),
                    ShimmerBox(width: 70, height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton loading for details page
class DetailsPageSkeleton extends StatelessWidget {
  const DetailsPageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrapper(
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Container(
              height: 200,
              color: Colors.grey[300],
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(child: ShimmerCircle(size: 100)),
                  const SizedBox(height: 16),
                  const Center(child: ShimmerBox(width: 200, height: 28)),
                  const SizedBox(height: 8),
                  const Center(child: ShimmerBox(width: 160, height: 18)),
                  const SizedBox(height: 32),
                  
                  // Info sections
                  ...List.generate(
                    4,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBox(width: 100, height: 14),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                ShimmerCircle(size: 40),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ShimmerBox(
                                      width: MediaQuery.of(context).size.width * 0.4,
                                      height: 16,
                                    ),
                                    const SizedBox(height: 6),
                                    ShimmerBox(
                                      width: MediaQuery.of(context).size.width * 0.25,
                                      height: 12,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
