import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/providers.dart';
import '../../../services/broadcast_service.dart';
import '../../../core/utils/helpers.dart';

/// Dialog for sending a broadcast notification from the dashboard's
/// Overview tab. Mirrors the original `_showBroadcastDialog` behavior but
/// delegates Firestore chunking to [BroadcastService].
class BroadcastDialog {
  BroadcastDialog._();

  /// Shows the broadcast dialog. [parentContext] must be the context that
  /// has access to [AdminProvider] (used to derive campus/department lists).
  static void show(BuildContext parentContext) {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    String selectedFilter = 'all';
    String? selectedCampus;
    String? selectedDepartment;
    bool isSending = false;

    final adminProvider = parentContext.read<AdminProvider>();
    final campuses = adminProvider.allUsers
        .map((u) => u.campusId)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final departments = adminProvider.allUsers
        .map((u) => u.department)
        .where((d) => d != null && d.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList()
      ..sort();

    showDialog(
      context: parentContext,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.campaign, color: Colors.orange),
              SizedBox(width: 8),
              Text('Send Broadcast'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g., Important Announcement',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title),
                  ),
                  maxLength: 50,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyController,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    hintText: 'Enter your message here...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.message),
                  ),
                  maxLines: 3,
                  maxLength: 200,
                ),
                const SizedBox(height: 16),
                const Text('Send to:'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ChoiceChip(
                      label: const Text('All Users'),
                      selected: selectedFilter == 'all',
                      onSelected: (_) =>
                          setDialogState(() => selectedFilter = 'all'),
                    ),
                    ChoiceChip(
                      label: const Text('Students Only'),
                      selected: selectedFilter == 'students',
                      onSelected: (_) =>
                          setDialogState(() => selectedFilter = 'students'),
                    ),
                    ChoiceChip(
                      label: const Text('All Leaders'),
                      selected: selectedFilter == 'leaders',
                      onSelected: (_) =>
                          setDialogState(() => selectedFilter = 'leaders'),
                    ),
                    ChoiceChip(
                      label: const Text('Student Leaders'),
                      selected: selectedFilter == 'studentLeaders',
                      onSelected: (_) => setDialogState(() =>
                          selectedFilter = 'studentLeaders'),
                    ),
                    ChoiceChip(
                      label: const Text('Org Officers'),
                      selected: selectedFilter == 'orgOfficers',
                      onSelected: (_) => setDialogState(
                          () => selectedFilter = 'orgOfficers'),
                    ),
                    ChoiceChip(
                      label: const Text('By Campus'),
                      selected: selectedFilter == 'campus',
                      onSelected: (_) => setDialogState(() {
                        selectedFilter = 'campus';
                        selectedCampus = null;
                      }),
                    ),
                    ChoiceChip(
                      label: const Text('By Department'),
                      selected: selectedFilter == 'department',
                      onSelected: (_) => setDialogState(() {
                        selectedFilter = 'department';
                        selectedDepartment = null;
                      }),
                    ),
                  ],
                ),
                if (selectedFilter == 'campus') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCampus,
                    decoration: const InputDecoration(
                      labelText: 'Campus',
                      border: OutlineInputBorder(),
                    ),
                    items: campuses
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(formatCampusName(c)),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => selectedCampus = v),
                  ),
                ],
                if (selectedFilter == 'department') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedDepartment,
                    decoration: const InputDecoration(
                      labelText: 'Department',
                      border: OutlineInputBorder(),
                    ),
                    items: departments
                        .map((d) => DropdownMenuItem(
                              value: d,
                              child: Text(d),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => selectedDepartment = v),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: isSending
                  ? null
                  : () async {
                      if (titleController.text.isEmpty ||
                          bodyController.text.isEmpty) {
                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Please fill in title and message'),
                          ),
                        );
                        return;
                      }
                      if ((selectedFilter == 'campus' &&
                              selectedCampus == null) ||
                          (selectedFilter == 'department' &&
                              selectedDepartment == null)) {
                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Please select a filter option'),
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isSending = true);

                      // Confirm before sending to all users
                      if (selectedFilter == 'all') {
                        final confirmed = await showDialog<bool>(
                          context: ctx,
                          builder: (context) => AlertDialog(
                            title: const Text('Send to all users?'),
                            content: const Text(
                              'This will send a notification to all users. Continue?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Send'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed != true) {
                          setDialogState(() => isSending = false);
                          return;
                        }
                      }

                      try {
                        final sentCount =
                            await BroadcastService.instance
                                .sendBroadcastToFilter(
                          title: titleController.text,
                          body: bodyController.text,
                          filter: selectedFilter,
                          campus: selectedCampus,
                          department: selectedDepartment,
                        );

                        if (ctx.mounted) Navigator.pop(ctx);
                        if (parentContext.mounted) {
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Broadcast sent to $sentCount users'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSending = false);
                        if (parentContext.mounted) {
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            SnackBar(
                              content: Text('Failed to send broadcast. Please try again.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              icon: isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label:
                  Text(isSending ? 'Sending...' : 'Send Broadcast'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    ).then((_) {
      titleController.dispose();
      bodyController.dispose();
    });
  }
}
