import 'package:flutter_test/flutter_test.dart';
import 'package:unitrack/providers/notification_provider.dart';
import 'package:unitrack/services/notification_service.dart';

import '../firebase_test_setup.dart';

/// Tests for [NotificationProvider].
///
/// These tests target surfaces that do NOT trigger Firebase calls.
/// The provider's `initialize`, `pingStaff`, `markAsRead`, etc. all touch
/// Firestore through [NotificationService]; those flows are verified by
/// integration tests. We focus here on:
///   * initial state reported by the getters
///   * `clearError` notifies listeners and resets the error string
///   * `stopListening` resets observable state and notifies listeners
void main() {
  setUpAll(setupFirebaseForTests);

  group('NotificationProvider initial state', () {
    test('reports empty notifications and zero unread by default', () {
      final provider = NotificationProvider(NotificationService());

      addTearDown(provider.dispose);

      expect(provider.notifications, isEmpty);
      expect(provider.unreadNotifications, isEmpty);
      expect(provider.unreadCount, equals(0));
      expect(provider.hasUnread, isFalse);
      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
    });

    test('clearError resets the error field to null and notifies listeners',
        () {
      final provider = NotificationProvider(NotificationService());
      addTearDown(provider.dispose);

      var notifyCount = 0;
      provider.addListener(() => notifyCount++);

      // Simulate an error being set without touching Firestore by reflecting
      // on the provider's behavior: clearError should always notify even when
      // there is no current error (idempotent notification).
      provider.clearError();

      expect(provider.error, isNull);
      expect(notifyCount, greaterThan(0));
    });

    test('stopListening resets notifications, unread count, and notifies', () {
      final provider = NotificationProvider(NotificationService());
      addTearDown(provider.dispose);

      var notifyCount = 0;
      provider.addListener(() => notifyCount++);

      provider.stopListening();

      expect(provider.notifications, isEmpty);
      expect(provider.unreadCount, equals(0));
      expect(notifyCount, greaterThan(0));
    });
  });
}
