import 'package:flutter/material.dart';

/// Responsive breakpoints following Material Design 3 guidelines
class Breakpoints {
  // Compact: phones in portrait
  static const double compact = 0; // 0-599
  // Medium: tablets in portrait, phones in landscape
  static const double medium = 600; // 600-839
  // Expanded: tablets in landscape, small desktop
  static const double expanded = 840; // 840-1199
  // Large: desktop
  static const double large = 1200; // 1200-1599
  // Extra large: large desktop monitors
  static const double extraLarge = 1600; // 1600+

  Breakpoints._();
}

/// Device type based on screen width
enum DeviceType {
  mobile, // compact: 0-599
  tablet, // medium + expanded: 600-1199
  desktop, // large + extraLarge: 1200+
}

/// Screen size category for finer control
enum ScreenSize {
  compact, // 0-599
  medium, // 600-839
  expanded, // 840-1199
  large, // 1200-1599
  extraLarge, // 1600+
}

/// Extension on BuildContext for easy responsive access
extension ResponsiveExtension on BuildContext {
  /// Get the current screen width
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// Get the current screen height
  double get screenHeight => MediaQuery.sizeOf(this).height;

  /// Get the current device type
  DeviceType get deviceType {
    final width = screenWidth;
    if (width < Breakpoints.medium) return DeviceType.mobile;
    if (width < Breakpoints.large) return DeviceType.tablet;
    return DeviceType.desktop;
  }

  /// Get the current screen size category
  ScreenSize get screenSize {
    final width = screenWidth;
    if (width < Breakpoints.medium) return ScreenSize.compact;
    if (width < Breakpoints.expanded) return ScreenSize.medium;
    if (width < Breakpoints.large) return ScreenSize.expanded;
    if (width < Breakpoints.extraLarge) return ScreenSize.large;
    return ScreenSize.extraLarge;
  }

  /// Check if current device is mobile (compact)
  bool get isMobile => screenWidth < Breakpoints.medium;

  /// Check if current device is tablet (medium-expanded)
  bool get isTablet =>
      screenWidth >= Breakpoints.medium && screenWidth < Breakpoints.large;

  /// Check if current device is desktop (large+)
  bool get isDesktop => screenWidth >= Breakpoints.large;

  /// Check if we should show a navigation rail (tablet/desktop)
  bool get showNavigationRail => screenWidth >= Breakpoints.medium;

  /// Check if we should show a full navigation drawer (desktop)
  bool get showNavigationDrawer => screenWidth >= Breakpoints.large;

  /// Get appropriate horizontal padding based on screen size
  double get responsivePadding {
    if (isMobile) return 16.0;
    if (isTablet) return 24.0;
    return 32.0;
  }

  /// Get appropriate grid columns based on screen size
  int get gridColumns {
    if (isMobile) return 1;
    if (isTablet) return 2;
    return 3;
  }

  /// Get max content width for centered layouts
  double get maxContentWidth {
    if (isMobile) return double.infinity;
    if (isTablet) return 720.0;
    return 1200.0;
  }
}

/// Widget that rebuilds based on breakpoint changes
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(
    BuildContext context,
    ScreenSize screenSize,
    DeviceType deviceType,
  )
  builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final ScreenSize screenSize;
        final DeviceType deviceType;

        if (width < Breakpoints.medium) {
          screenSize = ScreenSize.compact;
          deviceType = DeviceType.mobile;
        } else if (width < Breakpoints.expanded) {
          screenSize = ScreenSize.medium;
          deviceType = DeviceType.tablet;
        } else if (width < Breakpoints.large) {
          screenSize = ScreenSize.expanded;
          deviceType = DeviceType.tablet;
        } else if (width < Breakpoints.extraLarge) {
          screenSize = ScreenSize.large;
          deviceType = DeviceType.desktop;
        } else {
          screenSize = ScreenSize.extraLarge;
          deviceType = DeviceType.desktop;
        }

        return builder(context, screenSize, deviceType);
      },
    );
  }
}

/// Conditional widget that shows different content based on screen size
class ResponsiveVisibility extends StatelessWidget {
  final Widget child;
  final bool visibleOnMobile;
  final bool visibleOnTablet;
  final bool visibleOnDesktop;
  final Widget? replacement;

  const ResponsiveVisibility({
    super.key,
    required this.child,
    this.visibleOnMobile = true,
    this.visibleOnTablet = true,
    this.visibleOnDesktop = true,
    this.replacement,
  });

  @override
  Widget build(BuildContext context) {
    final deviceType = context.deviceType;

    final isVisible = switch (deviceType) {
      DeviceType.mobile => visibleOnMobile,
      DeviceType.tablet => visibleOnTablet,
      DeviceType.desktop => visibleOnDesktop,
    };

    if (isVisible) return child;
    return replacement ?? const SizedBox.shrink();
  }
}

/// Responsive grid that adjusts columns based on screen size
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int mobileColumns;
  final int tabletColumns;
  final int desktopColumns;
  final double spacing;
  final double runSpacing;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.mobileColumns = 1,
    this.tabletColumns = 2,
    this.desktopColumns = 3,
    this.spacing = 16,
    this.runSpacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    final columns = switch (context.deviceType) {
      DeviceType.mobile => mobileColumns,
      DeviceType.tablet => tabletColumns,
      DeviceType.desktop => desktopColumns,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: children.map((child) {
            return SizedBox(width: itemWidth, child: child);
          }).toList(),
        );
      },
    );
  }
}

/// Centered content container with max width
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsets? padding;
  final bool centered;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
    this.centered = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveMaxWidth = maxWidth ?? context.maxContentWidth;
    final effectivePadding =
        padding ?? EdgeInsets.symmetric(horizontal: context.responsivePadding);

    Widget content = Padding(padding: effectivePadding, child: child);

    if (effectiveMaxWidth != double.infinity) {
      content = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
        child: content,
      );
    }

    if (centered) {
      return Center(child: content);
    }

    return content;
  }
}
