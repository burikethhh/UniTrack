import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unitrack/models/user_model.dart';
import 'package:unitrack/models/location_model.dart';
import 'package:unitrack/models/faculty_with_location.dart';
import 'package:unitrack/widgets/common/faculty_card.dart';

/// Real widget tests for [FacultyCard].
/// Pumps the actual widget with a sample [FacultyWithLocation] and
/// verifies that the leader's name, department, and status render.
void main() {
  group('FacultyCard Widget', () {
    late UserModel leader;
    late LocationModel location;
    late FacultyWithLocation facultyWithLocation;

    setUp(() {
      leader = UserModel(
        id: 'leader-1',
        email: 'jane.smith@sksu.edu.ph',
        firstName: 'Jane',
        lastName: 'Smith',
        role: UserRole.studentLeader,
        campusId: 'isulan',
        department: 'College of Information and Computing Sciences',
        position: 'President',
        organization: 'SSC',
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
      );
      location = LocationModel(
        userId: 'leader-1',
        latitude: 6.633260,
        longitude: 124.609142,
        accuracy: 10.0,
        timestamp: DateTime.now(),
        isWithinCampus: true,
        status: 'Available',
        isManualPin: false,
      );
      facultyWithLocation = FacultyWithLocation(user: leader, location: location);
    });

    testWidgets('renders leader name, position, and status', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FacultyCard(
              faculty: facultyWithLocation,
              showQuickActions: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Jane Smith'), findsOneWidget);
      // Position • Department are joined (FacultyCard:72-75)
      expect(
        find.text('President • College of Information and Computing Sciences'),
        findsOneWidget,
      );
      // Status chip uses StatusBadge for 'Available'
      expect(find.text('Available'), findsWidgets);
    });

    testWidgets('fires onTap callback when card is tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FacultyCard(
              faculty: facultyWithLocation,
              showQuickActions: false,
              onTap: () => taps++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FacultyCard));
      await tester.pump();

      expect(taps, equals(1));
    });

    testWidgets('hides quick actions when showQuickActions is false',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FacultyCard(
              faculty: facultyWithLocation,
              showQuickActions: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // When showQuickActions is false, there should be no call/emailIcons
      expect(find.byIcon(Icons.call), findsNothing);
      expect(find.byIcon(Icons.email), findsNothing);
    });
  });

  group('FacultyCard Model Integration', () {
    test('FacultyWithLocation.isOnline is true when location is fresh and within-campus', () {
      final leader = UserModel(
        id: 'l1',
        email: 'l@sksu.edu.ph',
        firstName: 'L',
        lastName: 'D',
        role: UserRole.studentLeader,
        campusId: 'isulan',
        isActive: true,
        createdAt: DateTime.now(),
      );
      final loc = LocationModel(
        userId: 'l1',
        latitude: 6.633260,
        longitude: 124.609142,
        accuracy: 10.0,
        timestamp: DateTime.now(),
        isWithinCampus: true,
        isManualPin: false,
      );
      final fwl = FacultyWithLocation(user: leader, location: loc);

      expect(fwl.isOnline, isTrue);
    });

    test('FacultyWithLocation.isOnline is false when location is null', () {
      final leader = UserModel(
        id: 'l1',
        email: 'l@sksu.edu.ph',
        firstName: 'L',
        lastName: 'D',
        role: UserRole.studentLeader,
        campusId: 'isulan',
        isActive: true,
        createdAt: DateTime.now(),
      );
      final fwl = FacultyWithLocation(user: leader, location: null);

      expect(fwl.isOnline, isFalse);
    });
  });
}
