import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unitrack/widgets/common/custom_text_field.dart';

/// Widget tests for [CustomTextField].
/// Focus: label text renders; onChanged fires when text changes.
void main() {
  group('CustomTextField', () {
    testWidgets('renders the supplied label text', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomTextField(label: 'Email Address'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Email Address'), findsOneWidget);
    });

    testWidgets('invokes onChanged with the latest value when text changes',
        (WidgetTester tester) async {
      String? latest;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomTextField(
              label: 'Name',
              onChanged: (value) => latest = value,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(CustomTextField), 'Jane Doe');
      await tester.pump();

      expect(latest, equals('Jane Doe'));
    });
  });
}
