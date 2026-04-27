import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

// Test Constants
class TestConstants {
  static const String testUserId = 'test-user-123';
  static const String testEmail = 'test@example.com';
  static const String testPassword = 'password123';
  static const String testFirstName = 'John';
  static const String testLastName = 'Doe';
  static const String testCampusId = 'isulan';
  
  static Map<String, dynamic> get testUserData => {
    'id': testUserId,
    'email': testEmail,
    'firstName': testFirstName,
    'lastName': testLastName,
    'campusId': testCampusId,
    'role': 'student',
    'isActive': true,
    'createdAt': DateTime.now().toIso8601String(),
  };
}

// Mock Classes for Firebase
class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockUser extends Mock implements User {
  @override
  String get uid => TestConstants.testUserId;
  
  @override
  String? get email => TestConstants.testEmail;
}
class MockUserCredential extends Mock implements UserCredential {
  @override
  User? get user => MockUser();
}

// Widget Test Helper - Create a testable widget wrapper
Widget createTestableWidget({
  required Widget child,
  List<ChangeNotifierProvider>? providers,
}) {
  if (providers != null && providers.isNotEmpty) {
    return MultiProvider(
      providers: providers,
      child: MaterialApp(
        home: child,
      ),
    );
  }
  return MaterialApp(
    home: child,
  );
}

// Async Test Helper - Pump and settle with timeout
Future<void> pumpAndSettleWithTimeout(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  await tester.pumpAndSettle(timeout);
}

// Stream Helper for testing streams
Stream<T> createTestStream<T>(List<T> values, {Duration delay = const Duration(milliseconds: 100)}) async* {
  for (final value in values) {
    await Future.delayed(delay);
    yield value;
  }
}

// Golden File Helper - for widget testing
Matcher matchesGolden(String name) => matchesGoldenFile('goldens/$name.png');

// Test Fixtures
class TestFixtures {
  static Map<String, dynamic> createFacultyLocation({
    String userId = 'faculty-1',
    String userName = 'Dr. Smith',
    double latitude = 6.633260,
    double longitude = 124.609142,
    String status = 'available',
  }) {
    return {
      'userId': userId,
      'userName': userName,
      'latitude': latitude,
      'longitude': longitude,
      'status': status,
      'lastUpdated': DateTime.now().toIso8601String(),
      'accuracy': 10.0,
      'isManualPin': false,
    };
  }
}

// Accessibility Test Helper
void testAccessibility(WidgetTester tester, Widget widget) {
  expect(tester, meetsGuideline(textContrastGuideline));
  expect(tester, meetsGuideline(labeledTapTargetGuideline));
}
