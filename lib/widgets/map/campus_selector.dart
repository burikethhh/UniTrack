import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';

/// Campus selector dropdown for map navigation
class CampusSelector extends StatefulWidget {
  final String? selectedCampusId;
  final Function(String campusId) onCampusSelected;
  final bool compact;
  
  const CampusSelector({
    super.key,
    this.selectedCampusId,
    required this.onCampusSelected,
    this.compact = false,
  });
  
  @override
  State<CampusSelector> createState() => _CampusSelectorState();
}

class _CampusSelectorState extends State<CampusSelector> {
  bool _isExpanded = false;
  
  // Campus colors for visual distinction
  static const Map<String, Color> campusColors = {
    'isulan': AppColors.primary,
    'tacurong': Colors.orange,
    'access': Colors.purple,
    'bagumbayan': Colors.teal,
    'palimbang': Colors.indigo,
    'kalamansig': Colors.pink,
    'lutayan': Colors.brown,
  };
  
  Color _getCampusColor(String campusId) {
    return campusColors[campusId] ?? AppColors.primary;
  }
  
  @override
  Widget build(BuildContext context) {
    final campusList = AppConstants.campusList;
    final selectedCampus = widget.selectedCampusId != null
        ? campusList.firstWhere(
            (c) => c['id'] == widget.selectedCampusId,
            orElse: () => campusList.first,
          )
        : null;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Selector button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.compact ? 10 : 12,
                  vertical: widget.compact ? 8 : 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_city,
                      size: widget.compact ? 18 : 20,
                      color: selectedCampus != null
                          ? _getCampusColor(selectedCampus['id']!)
                          : AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      selectedCampus?['shortName'] ?? 'Select Campus',
                      style: TextStyle(
                        fontSize: widget.compact ? 12 : 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: widget.compact ? 18 : 20,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Dropdown list
          if (_isExpanded) ...[
            const Divider(height: 1),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: campusList.map((campus) {
                    final isSelected = campus['id'] == widget.selectedCampusId;
                    final color = _getCampusColor(campus['id']!);
                    
                    return Material(
                      color: isSelected
                          ? color.withValues(alpha: 0.1)
                          : Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _isExpanded = false;
                          });
                          widget.onCampusSelected(campus['id']!);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.3),
                                  border: Border.all(color: color, width: 2),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      campus['shortName']!,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? color
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle,
                                  size: 18,
                                  color: color,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A floating campus selector with modern design
class FloatingCampusSelector extends StatelessWidget {
  final String? selectedCampusId;
  final Function(String campusId) onCampusSelected;
  
  const FloatingCampusSelector({
    super.key,
    this.selectedCampusId,
    required this.onCampusSelected,
  });
  
  @override
  Widget build(BuildContext context) {
    return CampusSelector(
      selectedCampusId: selectedCampusId,
      onCampusSelected: onCampusSelected,
      compact: true,
    );
  }
}

/// Campus legend showing all campuses with colors - tap to navigate
class CampusLegend extends StatelessWidget {
  final bool expanded;
  final VoidCallback? onToggle;
  final String? selectedCampusId;
  final Function(String campusId)? onCampusSelected;
  
  const CampusLegend({
    super.key,
    this.expanded = false,
    this.onToggle,
    this.selectedCampusId,
    this.onCampusSelected,
  });
  
  // Campus colors for visual distinction
  static const Map<String, Color> campusColors = {
    'isulan': AppColors.primary,
    'tacurong': Colors.orange,
    'access': Colors.purple,
    'bagumbayan': Colors.teal,
    'palimbang': Colors.indigo,
    'kalamansig': Colors.pink,
    'lutayan': Colors.brown,
  };
  
  @override
  Widget build(BuildContext context) {
    final campusList = AppConstants.campusList;
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with toggle
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.layers,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                const Text(
                  'Campuses',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (onToggle != null) ...[
                  const SizedBox(width: 4),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                ],
              ],
            ),
          ),
          
          // Campus items - tap to navigate
          if (expanded) ...[
            const SizedBox(height: 6),
            ...campusList.map((campus) {
              final campusId = campus['id']!;
              final color = campusColors[campusId] ?? AppColors.primary;
              final isSelected = campusId == selectedCampusId;
              
              return InkWell(
                onTap: onCampusSelected != null 
                    ? () => onCampusSelected!(campusId)
                    : null,
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withValues(alpha: 0.1) : null,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.3),
                          border: Border.all(color: color, width: isSelected ? 2 : 1.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        campus['shortName']!,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? color : AppColors.textPrimary,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.check, size: 12, color: color),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ] else ...[
            const SizedBox(height: 4),
            Text(
              '${campusList.length} campuses',
              style: const TextStyle(
                fontSize: 9,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Status legend for faculty availability
class StatusLegend extends StatelessWidget {
  final bool compact;
  
  const StatusLegend({
    super.key,
    this.compact = false,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 8 : 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!compact)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                'Status',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          _buildLegendItem(AppColors.statusAvailable, 'Available'),
          const SizedBox(height: 4),
          _buildLegendItem(AppColors.statusBusy, 'Busy'),
          const SizedBox(height: 4),
          _buildLegendItem(AppColors.statusInClass, 'In Class'),
        ],
      ),
    );
  }
  
  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
