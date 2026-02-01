import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../core/theme/app_colors.dart';

/// Widget for displaying and selecting availability status
class AvailabilityStatusSelector extends StatelessWidget {
  final AvailabilityStatus? currentStatus;
  final String? customMessage;
  final ValueChanged<AvailabilityStatus> onStatusChanged;
  final ValueChanged<String>? onCustomMessageChanged;
  final bool showCustomMessage;

  const AvailabilityStatusSelector({
    super.key,
    this.currentStatus,
    this.customMessage,
    required this.onStatusChanged,
    this.onCustomMessageChanged,
    this.showCustomMessage = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Availability Status',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        
        // Status options
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AvailabilityStatus.values.map((status) {
            final isSelected = currentStatus == status;
            return _StatusChip(
              status: status,
              isSelected: isSelected,
              onTap: () => onStatusChanged(status),
            );
          }).toList(),
        ),
        
        // Custom message input
        if (showCustomMessage && onCustomMessageChanged != null) ...[
          const SizedBox(height: 16),
          TextFormField(
            initialValue: customMessage,
            decoration: InputDecoration(
              labelText: 'Custom Status Message (Optional)',
              hintText: 'e.g., "Back at 2 PM"',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.message_outlined),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            maxLength: 100,
            onChanged: onCustomMessageChanged,
          ),
        ],
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final AvailabilityStatus status;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusChip({
    required this.status,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? status.color : Colors.grey[100],
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? status.color : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: status.color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                status.icon,
                size: 18,
                color: isSelected ? Colors.white : status.color,
              ),
              const SizedBox(width: 6),
              Text(
                status.displayName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact status badge for displaying in lists/cards
class AvailabilityStatusBadge extends StatelessWidget {
  final AvailabilityStatus? status;
  final String? customMessage;
  final bool showLabel;
  final double size;

  const AvailabilityStatusBadge({
    super.key,
    this.status,
    this.customMessage,
    this.showLabel = true,
    this.size = 12,
  });

  @override
  Widget build(BuildContext context) {
    if (status == null) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: status!.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: status!.color.withOpacity(0.4),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
        if (showLabel) ...[
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              customMessage?.isNotEmpty == true
                  ? customMessage!
                  : status!.displayName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: status!.color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}

/// Inline status indicator for profile/header
class AvailabilityStatusIndicator extends StatelessWidget {
  final AvailabilityStatus? status;
  final String? customMessage;
  final VoidCallback? onTap;

  const AvailabilityStatusIndicator({
    super.key,
    this.status,
    this.customMessage,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (status == null) {
      return _buildSetStatusButton();
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: status!.color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: status!.color.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: status!.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              status!.icon,
              size: 16,
              color: status!.color,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                customMessage?.isNotEmpty == true
                    ? customMessage!
                    : status!.displayName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: status!.color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.edit,
                size: 14,
                color: status!.color.withOpacity(0.7),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSetStatusButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.add_circle_outline,
            size: 16,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 6),
          Text(
            'Set Status',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet for changing status
class AvailabilityStatusBottomSheet extends StatefulWidget {
  final AvailabilityStatus? currentStatus;
  final String? customMessage;
  final void Function(AvailabilityStatus status, String? customMessage) onSave;

  const AvailabilityStatusBottomSheet({
    super.key,
    this.currentStatus,
    this.customMessage,
    required this.onSave,
  });

  static Future<void> show({
    required BuildContext context,
    AvailabilityStatus? currentStatus,
    String? customMessage,
    required void Function(AvailabilityStatus status, String? customMessage) onSave,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => AvailabilityStatusBottomSheet(
        currentStatus: currentStatus,
        customMessage: customMessage,
        onSave: onSave,
      ),
    );
  }

  @override
  State<AvailabilityStatusBottomSheet> createState() =>
      _AvailabilityStatusBottomSheetState();
}

class _AvailabilityStatusBottomSheetState
    extends State<AvailabilityStatusBottomSheet> {
  late AvailabilityStatus? _selectedStatus;
  late TextEditingController _messageController;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.currentStatus;
    _messageController = TextEditingController(text: widget.customMessage);
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _save() {
    if (_selectedStatus != null) {
      widget.onSave(_selectedStatus!, _messageController.text.trim());
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          const Text(
            'Set Your Status',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Let others know your availability',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),

          // Status options
          ...AvailabilityStatus.values.map((status) => _StatusOption(
                status: status,
                isSelected: _selectedStatus == status,
                onTap: () {
                  setState(() {
                    _selectedStatus = status;
                  });
                },
              )),

          const SizedBox(height: 20),

          // Custom message
          TextField(
            controller: _messageController,
            decoration: InputDecoration(
              labelText: 'Custom Message (Optional)',
              hintText: 'e.g., "Back at 2:30 PM"',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
              prefixIcon: const Icon(Icons.edit_note),
            ),
            maxLength: 100,
          ),
          const SizedBox(height: 20),

          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedStatus != null ? _save : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Save Status',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusOption extends StatelessWidget {
  final AvailabilityStatus status;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusOption({
    required this.status,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? status.color.withOpacity(0.1)
                  : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? status.color : Colors.grey[200]!,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: status.color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    status.icon,
                    color: status.color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    status.displayName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color:
                          isSelected ? status.color : Colors.grey[800],
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: status.color,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
