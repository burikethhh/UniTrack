import 'package:flutter_test/flutter_test.dart';
import 'package:unitrack/services/database_service.dart';

import '../firebase_test_setup.dart';

/// Tests for [DatabaseService].
///
/// The service hard-codes `FirebaseFirestore.instance` (no injection), so we
/// rely on the [setupFirebaseForTests] helper to install a mock Firebase core
/// that lets `Firestore` collection references be CONSTRUCTED. We only call
/// surfaces whose behavior can be verified with the mock:
///
///   * `searchFaculty('')` / `searchFaculty('   ')` -> early return of `[]`
///     without any Firestore operation (line 61 of database_service.dart).
///   * `getUserCounts()` always wraps the Firestore `count()` calls in a
///     try/catch that returns the zero-map `{students:0, faculty:0, admins:0,
///     total:0}` on ANY exception – and the firebase_core mock does NOT
///     implement Firestore's `count().get()` API, guaranteeing that path
///     is taken without further mocking.
void main() {
  setUpAll(setupFirebaseForTests);

  group('DatabaseService.searchFaculty', () {
    test('returns an empty list for an empty query (no Firestore calls)', () async {
      final service = DatabaseService();
      final result = await service.searchFaculty('');

      expect(result, isEmpty);
    });

    test('returns an empty list for a whitespace-only query', () async {
      final service = DatabaseService();
      final result = await service.searchFaculty('     ');

      expect(result, isEmpty);
    });
  });

  group('DatabaseService.getUserCounts', () {
    test('returns the zero map when Firestore operations throw', () async {
      final service = DatabaseService();

      final counts = await service.getUserCounts();

      expect(counts, isA<Map<String, int>>());
      expect(counts['students'], equals(0));
      expect(counts['faculty'], equals(0));
      expect(counts['admins'], equals(0));
      expect(counts['total'], equals(0));
    });
  });

  group('DatabaseService class structure', () {
    test('can be instantiated with the mock Firebase in place', () {
      expect(DatabaseService, isA<Type>());
      expect(() => DatabaseService(), returnsNormally);
    });
  });
}
