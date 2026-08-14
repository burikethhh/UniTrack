import 'package:flutter/material.dart';
import '../../core/constants/map_constants.dart';
import '../../core/theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────
//  Map View Mode Dropdown
// ─────────────────────────────────────────────────────────────

/// A compact dropdown button that lets the user switch between
/// Satellite, 3D, and Ground map modes.
class MapViewModeDropdown extends StatelessWidget {
  final MapViewMode currentMode;
  final ValueChanged<MapViewMode> onModeChanged;

  const MapViewModeDropdown({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
  });

  static const _modes = [
    (
      mode: MapViewMode.satellite,
      icon: Icons.satellite_alt,
      label: 'Satellite',
    ),
    (
      mode: MapViewMode.buildings3D,
      icon: Icons.location_city,
      label: '3D Buildings',
    ),
    (
      mode: MapViewMode.groundLevel,
      icon: Icons.streetview,
      label: 'Ground Level',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final current = _modes.firstWhere((m) => m.mode == currentMode);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 3,
      child: PopupMenuButton<MapViewMode>(
        onSelected: onModeChanged,
        offset: const Offset(0, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        itemBuilder: (_) => _modes.map((m) {
          final selected = m.mode == currentMode;
          return PopupMenuItem<MapViewMode>(
            value: m.mode,
            child: Row(
              children: [
                Icon(
                  m.icon,
                  size: 18,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Text(
                  m.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    color: selected ? AppColors.primary : Colors.black87,
                  ),
                ),
                if (selected) ...[
                  const Spacer(),
                  const Icon(Icons.check, size: 16, color: AppColors.primary),
                ],
              ],
            ),
          );
        }).toList(),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(current.icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                current.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_drop_down,
                size: 20,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Tracking Mode Dropdown (Faculty only)
// ─────────────────────────────────────────────────────────────

