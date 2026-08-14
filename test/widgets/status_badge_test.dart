import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unitrack/widgets/common/status_badge.dart';
import 'package:unitrack/core/theme/app_colors.dart';

/// Widget tests for [StatusBadge].
/// Focus: badge picks the right color for a known status string.
void main() {
  group('StatusBadge', () {
    testWidgets('uses the correct color for the "busy" status',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: StatusBadge(status: 'busy'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The badge text Color is the same color returned by getStatusColor.
      final Text text = tester.widget(find.text('busy'));
      expect(text.style?.color, equals(AppColors.statusBusy));
    });

    testWidgets('falls back to statusAway for unknown status strings',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: StatusBadge(status: 'something-unknown'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Text text = tester.widget(find.text('something-unknown'));
      expect(text.style?.color, equals(AppColors.statusAway));
    });
  });
}
