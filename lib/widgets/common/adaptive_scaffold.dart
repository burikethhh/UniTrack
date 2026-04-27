import 'package:flutter/material.dart';
import '../../core/utils/responsive.dart';
import '../../core/theme/app_colors.dart';

/// Navigation destination for adaptive navigation
class AdaptiveDestination {
  final IconData icon;
  final IconData? selectedIcon;
  final String label;
  final Widget screen;

  const AdaptiveDestination({
    required this.icon,
    this.selectedIcon,
    required this.label,
    required this.screen,
  });
}

/// An adaptive scaffold that switches between:
/// - Bottom navigation bar (mobile)
/// - Navigation rail (tablet)
/// - Navigation drawer (desktop)
class AdaptiveScaffold extends StatefulWidget {
  final String title;
  final List<AdaptiveDestination> destinations;
  final int initialIndex;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const AdaptiveScaffold({
    super.key,
    required this.title,
    required this.destinations,
    this.initialIndex = 0,
    this.actions,
    this.floatingActionButton,
    this.showBackButton = false,
    this.onBackPressed,
  });

  @override
  State<AdaptiveScaffold> createState() => _AdaptiveScaffoldState();
}

class _AdaptiveScaffoldState extends State<AdaptiveScaffold> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onDestinationSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, screenSize, deviceType) {
        return switch (deviceType) {
          DeviceType.mobile => _buildMobileLayout(context),
          DeviceType.tablet => _buildTabletLayout(context),
          DeviceType.desktop => _buildDesktopLayout(context),
        };
      },
    );
  }

  /// Mobile layout: Traditional bottom navigation bar
  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: widget.showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBackPressed ?? () => Navigator.pop(context),
              )
            : null,
        actions: widget.actions,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: widget.destinations.map((d) => d.screen).toList(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: widget.destinations.map((dest) {
          return NavigationDestination(
            icon: Icon(dest.icon),
            selectedIcon: Icon(dest.selectedIcon ?? dest.icon),
            label: dest.label,
          );
        }).toList(),
      ),
      floatingActionButton: widget.floatingActionButton,
    );
  }

  /// Tablet layout: Navigation rail on the left
  Widget _buildTabletLayout(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: widget.showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBackPressed ?? () => Navigator.pop(context),
              )
            : null,
        actions: widget.actions,
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _currentIndex,
            onDestinationSelected: _onDestinationSelected,
            labelType: NavigationRailLabelType.all,
            backgroundColor: AppColors.surface,
            destinations: widget.destinations.map((dest) {
              return NavigationRailDestination(
                icon: Icon(dest.icon),
                selectedIcon: Icon(dest.selectedIcon ?? dest.icon),
                label: Text(dest.label),
              );
            }).toList(),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: widget.destinations.map((d) => d.screen).toList(),
            ),
          ),
        ],
      ),
      floatingActionButton: widget.floatingActionButton,
    );
  }

  /// Desktop layout: Expanded navigation drawer
  Widget _buildDesktopLayout(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Permanent navigation drawer
          SizedBox(
            width: 280,
            child: Drawer(
              elevation: 0,
              shape: const RoundedRectangleBorder(),
              child: Column(
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(color: AppColors.primary),
                    child: SafeArea(
                      bottom: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.location_on,
                                  color: AppColors.primary,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                widget.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Navigation items
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: widget.destinations.length,
                      itemBuilder: (context, index) {
                        final dest = widget.destinations[index];
                        final isSelected = index == _currentIndex;

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          child: ListTile(
                            leading: Icon(
                              isSelected
                                  ? (dest.selectedIcon ?? dest.icon)
                                  : dest.icon,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                            title: Text(
                              dest.label,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                              ),
                            ),
                            selected: isSelected,
                            selectedTileColor: AppColors.primary.withValues(
                              alpha: 0.1,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            onTap: () => _onDestinationSelected(index),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          const VerticalDivider(thickness: 1, width: 1),

          // Main content
          Expanded(
            child: Column(
              children: [
                // Top bar
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.divider.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        widget.destinations[_currentIndex].label,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (widget.actions != null) ...widget.actions!,
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: widget.destinations.map((d) => d.screen).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: widget.floatingActionButton,
    );
  }
}
