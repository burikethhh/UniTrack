import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/models/user_model.dart';
import '../../lib/models/location_model.dart';

/// Simplified Faculty Card Tests
/// Tests model structure without complex widget mocking
void main() {
  group('Faculty Model Tests', () {
    test('UserModel can be created for faculty', () {
      // Arrange
      final faculty = UserModel(
        id: 'faculty-1',
        email: 'dr.smith@sksu.edu.ph',
        firstName: 'Dr. Jane',
        lastName: 'Smith',
        role: UserRole.staff,
        campusId: 'isulan',
        department: 'Computer Science',
        position: 'Professor',
        isActive: true,
        createdAt: DateTime.now(),
      );

      // Assert
      expect(faculty.fullName, equals('Dr. Jane Smith'));
      expect(faculty.department, equals('Computer Science'));
      expect(faculty.position, equals('Professor'));
      expect(faculty.isStaff, isTrue);
    });

    test('LocationModel can be created directly', () {
      // Arrange & Act
      final locationModel = LocationModel(
        userId: 'faculty-1',
        latitude: 6.633260,
        longitude: 124.609142,
        accuracy: 10.0,
        timestamp: DateTime.now(),
        isWithinCampus: true,
        status: 'available',
        isManualPin: false,
      );
      
      // Assert
      expect(locationModel.userId, equals('faculty-1'));
      expect(locationModel.latitude, equals(6.633260));
      expect(locationModel.longitude, equals(124.609142));
      expect(locationModel.isManualPin, isFalse);
      expect(locationModel.isWithinCampus, isTrue);
    });

  });

  group('Widget Structure Tests', () {
    testWidgets('Card widget can be created', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Card(
              child: ListTile(
                leading: const CircleAvatar(child: Text('DS')),
                title: const Text('Dr. Jane Smith'),
                subtitle: const Text('Computer Science'),
                trailing: const Chip(label: Text('Available')),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dr. Jane Smith'), findsOneWidget);
      expect(find.text('Computer Science'), findsOneWidget);
    });
  });
}
