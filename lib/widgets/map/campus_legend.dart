import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';

/// Expandable campus legend shown on the student map screen.
/// Collapsed: shows only the currently selected campus chip.
/// Expanded: lists all campuses as tappable chips.
class CampusLegend extends StatelessWidget {
  final bool expanded;
  final String selectedCampusId;
  final VoidCallback onToggle;
  final ValueChanged<String> onCampusSelected;

  const CampusLegend({
    super.key,
    required this.expanded,
    required this.selectedCampusId,
    required this.onToggle,
    required this.onCampusSelected,
  });

  @override
  Widget build(BuildContext context) {
    final selectedCampus = AppConstants.campusesData.firstWhere(
      (c) => c['id'] == selectedCampusId,
      orElse: () => AppConstants.campusesData.first,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: onToggle,
        child: expanded ? _buildExpanded(context) : _buildCollapsed(selectedCampus),
      ),
    );
  }

  Widget _buildCollapsed(Map<String, dynamic> campus) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.school, size: 16, color: AppColors.accent),
          const SizedBox(width: 6),
          Text(
            campus['shortName'] as String? ?? campus['name'] as String? ?? '',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.expand_more,
            size: 16,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildExpanded(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 200),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
            child: Row(
              children: [
                Icon(Icons.school, size: 16, color: AppColors.accent),
                const SizedBox(width: 6),
                Text(
                  'Campuses',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onToggle,
                  child: Icon(
                    Icons.expand_less,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...AppConstants.campusesData.map((campus) {
            final isSelected = campus['id'] == selectedCampusId;
            return InkWell(
              onTap: () => onCampusSelected(campus['id'] as String),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      size: 14,
                      color: isSelected ? AppColors.accent : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        campus['name'] as String? ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected ? AppColors.accent : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
