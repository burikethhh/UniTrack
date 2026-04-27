/// Test Runner for UniTrack
/// 
/// This file runs all unit, provider, and widget tests.
/// 
/// Run individual test suites:
/// ```bash
/// flutter test test/unit/
/// flutter test test/providers/
/// flutter test test/widgets/
/// ```
///
/// Run with coverage:
/// ```bash
/// flutter test --coverage
/// ```
///
/// Generate coverage report:
/// ```bash
/// genhtml coverage/lcov.info -o coverage/html
/// ```

import 'package:flutter_test/flutter_test.dart';

// Unit Tests
import 'unit/auth_service_test.dart' as auth_service_test;
import 'unit/location_service_test.dart' as location_service_test;

// Provider Tests
import 'providers/auth_provider_test.dart' as auth_provider_test;

// Widget Tests
import 'widgets/login_screen_test.dart' as login_screen_test;
import 'widgets/faculty_card_test.dart' as faculty_card_test;

void main() {
  group('UniTrack Test Suite', () {
    group('Unit Tests', () {
      auth_service_test.main();
      location_service_test.main();
    });

    group('Provider Tests', () {
      auth_provider_test.main();
    });

    group('Widget Tests', () {
      login_screen_test.main();
      faculty_card_test.main();
    });
  });
}
