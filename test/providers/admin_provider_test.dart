import 'package:flutter_test/flutter_test.dart';
import 'package:unitrack/providers/admin_provider.dart';
import 'package:unitrack/models/user_model.dart';

import '../firebase_test_setup.dart';

/// Tests for [AdminProvider] initial state.
///
/// Instantiating [AdminProvider] does not touch Firestore operationally —
/// only calls to `initialize`, `loadAllUsers`, `loadStatistics`, `banUser`,
/// etc. do. We initialize a mock Firebase app so the field-initializer
/// `FirebaseFirestore.instance` inside [AdminProvider] does not throw,
/// then focus on the freshly-constructed state and on computed getters
/// that operate on the local `_allUsers` list (`search`, `getUserById`,
/// `clearFilters`).
void main() {
  setUpAll(setupFirebaseForTests);

  group('AdminProvider initial state', () {
    test('isLoading is false and user lists are empty by default', () {
      final provider = AdminProvider();
      addTearDown(provider.dispose);

      expect(provider.isLoading, isFalse);
      expect(provider.allUsers, isEmpty);
      expect(provider.filteredUsers, isEmpty);
      expect(provider.students, isEmpty);
      expect(provider.admins, isEmpty);
      expect(provider.bannedUsers, isEmpty);
    });

    test('default filters are unset and statistics are zeroed', () {
      final provider = AdminProvider();
      addTearDown(provider.dispose);

      expect(provider.searchQuery, isEmpty);
      expect(provider.roleFilter, isNull);
      expect(provider.campusFilter, isNull);
      expect(provider.showBannedOnly, isFalse);
      expect(provider.error, isNull);

      final stats = provider.statistics;
      expect(stats.totalUsers, equals(0));
      expect(stats.totalStudents, equals(0));
      expect(stats.totalAdmins, equals(0));
      expect(stats.onlineNow, equals(0));
    });
  });

  group('AdminProvider computed getters', () {
    test('getUserById returns null when the list is empty', () {
      final provider = AdminProvider();
      addTearDown(provider.dispose);

      expect(provider.getUserById('does-not-exist'), isNull);
    });

    test('search with a query sets searchQuery (no Firebase calls)', () {
      final provider = AdminProvider();
      addTearDown(provider.dispose);

      var notifyCount = 0;
      provider.addListener(() => notifyCount++);

      provider.search('Jane');

      expect(provider.searchQuery, equals('Jane'));
      expect(notifyCount, greaterThan(0));
    });

    test('setRoleFilter / clearFilters mutate state and notify listeners', () {
      final provider = AdminProvider();
      addTearDown(provider.dispose);

      var notifyCount = 0;
      provider.addListener(() => notifyCount++);

      provider.setRoleFilter(UserRole.admin);
      expect(provider.roleFilter, equals(UserRole.admin));

      provider.clearFilters();
      expect(provider.roleFilter, isNull);
      expect(provider.campusFilter, isNull);
      expect(provider.showBannedOnly, isFalse);
      expect(provider.searchQuery, isEmpty);

      expect(notifyCount, greaterThan(1));
    });
  });
}
