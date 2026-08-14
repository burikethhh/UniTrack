import 'package:flutter_test/flutter_test.dart';
import 'package:unitrack/models/location_model.dart';
import 'package:unitrack/models/user_model.dart';

void main() {
  group('AvailabilityStatus', () {
    test('normalizes legacy and canonical labels', () {
      expect(
        AvailabilityStatusExtension.fromString('Available for Consultation'),
        AvailabilityStatus.available,
      );
      expect(
        AvailabilityStatusExtension.fromString(' in-meeting '),
        AvailabilityStatus.inMeeting,
      );
      expect(
        AvailabilityStatusExtension.fromString('Out of Office'),
        AvailabilityStatus.outOfOffice,
      );
      expect(AvailabilityStatusExtension.fromString('unknown'), isNull);
    });
  });

  group('LocationModel', () {
    test('serializes broadcast scope and campus metadata', () {
      final expiresAt = DateTime(2026, 8, 11, 12);
      final location = LocationModel(
        userId: 'leader-1',
        latitude: 6.63,
        longitude: 124.61,
        timestamp: DateTime(2026, 8, 11, 10),
        locationCampusId: 'isulan',
        visibilityScope: LocationVisibilityScope.universityWide,
        statusExpiresAt: expiresAt,
      );

      final data = location.toFirestore();

      expect(data['userId'], 'leader-1');
      expect(data['locationCampusId'], 'isulan');
      expect(data['visibilityScope'], 'universityWide');
      expect(data['statusExpiresAt'], isNotNull);
    });

    test('copyWith can clear nullable status metadata', () {
      final location = LocationModel(
        userId: 'leader-1',
        latitude: 6.63,
        longitude: 124.61,
        timestamp: DateTime.now(),
        status: 'Busy',
        statusExpiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      final cleared = location.copyWith(status: null, statusExpiresAt: null);

      expect(cleared.status, isNull);
      expect(cleared.statusExpiresAt, isNull);
    });
  });
}
