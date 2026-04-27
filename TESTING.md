# UniTrack Testing Guide

This project includes comprehensive unit, provider, widget, and integration tests.

## Test Structure

```
test/
├── test_helpers.dart              # Shared test utilities and fixtures
├── widget_test.dart               # Basic smoke tests
├── all_tests.dart                 # Test runner for all suites
├── unit/
│   ├── auth_service_test.dart     # AuthService unit tests
│   └── location_service_test.dart # LocationService unit tests
├── providers/
│   └── auth_provider_test.dart    # AuthProvider state management tests
├── widgets/
│   ├── login_screen_test.dart     # LoginScreen widget tests
│   └── faculty_card_test.dart    # FacultyCard widget tests
└── integration/
    └── app_flow_test.dart         # End-to-end integration tests
```

## Running Tests

### Run All Tests
```bash
flutter test
```

### Run Specific Test Files
```bash
# Unit tests only
flutter test test/unit/

# Provider tests only
flutter test test/providers/

# Widget tests only
flutter test test/widgets/

# Integration tests
flutter test integration_test/app_flow_test.dart
```

### Run with Coverage
```bash
flutter test --coverage
```

### Generate HTML Coverage Report
```bash
# Install lcov if not already installed
# On macOS: brew install lcov
# On Linux: sudo apt-get install lcov

# Generate HTML report
genhtml coverage/lcov.info -o coverage/html

# Open report
open coverage/html/index.html
```

## Test Categories

### Unit Tests
Test individual service classes in isolation with mocked dependencies.

**AuthService Tests:**
- `signInWithEmailPassword` - success, failure, timeout, retry logic
- `signOut` - successful logout, error handling
- `getCurrentUserModel` - user retrieval, null cases
- `authStateChanges` - stream of auth state

**LocationService Tests:**
- `checkAndRequestPermission` - granted, denied, permanently denied
- Location configuration validation
- Position accuracy validation
- Position smoothing algorithm
- Manual pin mode operations
- Movement detection

### Provider Tests
Test ChangeNotifier state management with mocked services.

**AuthProvider Tests:**
- Initial state validation
- Sign-in flow with loading states
- Role detection (student, staff, admin)
- Error handling and clearing
- Auth state listener behavior

### Widget Tests
Test UI components in isolation.

**LoginScreen Tests:**
- UI element presence (logo, fields, buttons)
- Form validation (email format, password length)
- Password visibility toggle
- Loading state display
- Error message display
- Accessibility compliance

**FacultyCard Tests:**
- Information display (name, department, position)
- Status color coding (available=green, busy=yellow, etc.)
- Avatar display (initials vs photo)
- On-campus indicator
- Offline state handling
- Compact mode behavior

### Integration Tests
Test complete user flows across multiple screens.

**App Flow Tests:**
- App launch and splash screen
- Login flow (requires Firebase Auth Emulator for real tests)
- Navigation between screens

## Dependency Injection & Testability

Both `AuthService` and `LocationService` support dependency injection for testing:

```dart
// Production code
final authService = AuthService();
final locationService = LocationService();

// Test code with mocks
final mockAuth = MockFirebaseAuth();
final mockFirestore = MockFirebaseFirestore();
final authService = AuthService.testable(
  auth: mockAuth,
  firestore: mockFirestore,
);

final mockGeolocator = MockGeolocator();
final locationService = LocationService.testable(
  firestore: mockFirestore,
  geolocator: mockGeolocator,
);
```

## Mock Generation

Generate mock classes using build_runner:

```bash
flutter pub run build_runner build
```

This generates `.mocks.dart` files for classes annotated with `@GenerateMocks`.

## Test Fixtures

Common test data is available in `test/test_helpers.dart`:

```dart
TestConstants.testUserId
TestConstants.testEmail
TestConstants.testUserData
TestFixtures.createFacultyLocation()
```

## Writing New Tests

### Unit Test Template
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import '../test_helpers.dart';

void main() {
  group('ServiceName Tests', () {
    late ServiceName service;
    
    setUp(() {
      service = ServiceName.testable(/* mocks */);
    });
    
    tearDown(() {
      service.dispose(); // Clean up
    });
    
    test('should do something', () {
      // Arrange
      when(mock.dependency()).thenReturn(value);
      
      // Act
      final result = service.method();
      
      // Assert
      expect(result, expectedValue);
      verify(mock.dependency()).called(1);
    });
  });
}
```

### Widget Test Template
```dart
import 'package:flutter_test/flutter_test.dart';
import '../test_helpers.dart';

void main() {
  testWidgets('Widget behaves correctly', (WidgetTester tester) async {
    // Arrange
    await tester.pumpWidget(createTestableWidget(
      child: MyWidget(),
    ));
    await tester.pumpAndSettle();
    
    // Act
    await tester.tap(find.text('Button'));
    await tester.pumpAndSettle();
    
    // Assert
    expect(find.text('Result'), findsOneWidget);
  });
}
```

## Continuous Integration

Add to your CI pipeline (GitHub Actions example):

```yaml
- name: Run Tests
  run: flutter test

- name: Run Tests with Coverage
  run: flutter test --coverage

- name: Upload Coverage
  uses: codecov/codecov-action@v3
  with:
    file: coverage/lcov.info
```

## Troubleshooting

### "Firebase not initialized" errors
Integration tests need Firebase to be initialized. Use Firebase Auth Emulator or mock Firebase in unit tests.

### Mock classes not found
Run `flutter pub run build_runner build` to generate mock files.

### Golden file tests failing
Golden files are platform-specific. Generate them on the same platform running CI:
```bash
flutter test --update-goldens
```

### Tests timing out
Increase timeout for async operations:
```dart
await tester.pumpAndSettle(const Duration(seconds: 5));
```

## Best Practices

1. **Test behavior, not implementation** - Test what the code does, not how it does it
2. **One assertion per test** - Keep tests focused and readable
3. **Use descriptive test names** - `test('throws exception on invalid email')` > `test('error test')`
4. **Mock external dependencies** - Don't call real Firebase/HTTP in unit tests
5. **Clean up resources** - Always dispose services in `tearDown`
6. **Test edge cases** - Empty inputs, null values, boundary conditions
7. **Use test fixtures** - Reusable test data in `test_helpers.dart`
