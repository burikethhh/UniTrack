import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unitrack/widgets/common/custom_button.dart';

/// Widget tests for [PrimaryButton].
/// Focus: onTap fires when enabled, suppressed when disabled.
void main() {
  group('PrimaryButton', () {
    testWidgets('fires onTap when enabled', (WidgetTester tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrimaryButton(
              text: 'Submit',
              onPressed: () => taps++,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(PrimaryButton));
      await tester.pump();

      expect(taps, equals(1));
    });

    testWidgets('suppresses tap when onPressed is null (disabled)',
        (WidgetTester tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrimaryButton(
              text: 'Submit',
              onPressed: null,
            ),
          ),
        ),
      );

      // When disabled, the inner `InkWell` is given `onTap: null`, so the
      // framework does not register a tap gesture target. Verify that the
      // InkWell widget inside the button has a null onTap and that nothing
      // increments the counter.
      final InkWell ink = tester.widget<InkWell>(
        find.descendant(
          of: find.byType(PrimaryButton),
          matching: find.byType(InkWell),
        ),
      );
      expect(ink.onTap, isNull);
      expect(taps, equals(0));
    });
  });
}
