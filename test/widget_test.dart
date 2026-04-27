// This is a basic Flutter widget test for UniTrack.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unitrack/core/theme/app_theme.dart';

import 'test_helpers.dart';

void main() {
  group('UniTrack Smoke Tests', () {
    testWidgets('App theme loads correctly', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: Center(child: Text('Test')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Test'), findsOneWidget);
      expect(Theme.of(tester.element(find.text('Test'))).brightness, equals(Brightness.light));
    });

    testWidgets('MaterialApp initializes with correct structure', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        createTestableWidget(
          child: Scaffold(
            appBar: AppBar(title: const Text('Test App')),
            body: const Center(child: Text('Hello UniTrack')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Test App'), findsOneWidget);
      expect(find.text('Hello UniTrack'), findsOneWidget);
    });

    testWidgets('Test helpers work correctly', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        createTestableWidget(
          child: const Column(
            children: [
              Text(TestConstants.testFirstName),
              Text(TestConstants.testLastName),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.text(TestConstants.testFirstName), findsOneWidget);
      expect(find.text(TestConstants.testLastName), findsOneWidget);
    });
  });
}
