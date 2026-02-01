import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/notification_model.dart';
import '../models/user_model.dart';

/// Service for handling notifications between students and staff
class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  StreamSubscription? _notificationSubscription;

  /// Initialize local notifications
  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // Can navigate to specific screen based on payload
  }

  /// Start listening for notifications for a specific user
  /// Note: Using client-side filtering to avoid composite index requirement
  void startListening(String userId) {
    _notificationSubscription?.cancel();
    
    _notificationSubscription = _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final notification = AppNotification.fromFirestore(change.doc);
          // Only show local notification for unread notifications
          if (!notification.isRead) {
            _showLocalNotification(notification);
          }
        }
      }
    }, onError: (e) {
      debugPrint('Error listening to notifications: $e');
    });
  }

  /// Stop listening for notifications
  void stopListening() {
    _notificationSubscription?.cancel();
    _notificationSubscription = null;
  }

  /// Show a local notification
  Future<void> _showLocalNotification(AppNotification notification) async {
    const androidDetails = AndroidNotificationDetails(
      'unitrack_notifications',
      'UniTrack Notifications',
      channelDescription: 'Notifications for UniTrack app',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _localNotifications.show(
      notification.id.hashCode,
      notification.title,
      notification.message,
      details,
      payload: notification.id,
    );
  }

  /// Send a "looking for you" notification from student to staff
  Future<bool> sendLookingForYouNotification({
    required UserModel student,
    required String staffId,
    required String staffName,
    String? studentLocation,
  }) async {
    try {
      final notification = AppNotification(
        id: '', // Will be set by Firestore
        senderId: student.id,
        senderName: student.fullName,
        senderPhotoUrl: student.photoUrl,
        recipientId: staffId,
        type: NotificationType.lookingForYou,
        title: 'Student Looking for You',
        message: '${student.fullName} is looking for you',
        createdAt: DateTime.now(),
        isRead: false,
        data: {
          'studentDepartment': student.department,
          'studentLocation': studentLocation,
        },
      );

      await _firestore.collection('notifications').add(notification.toFirestore());
      
      debugPrint('📢 Notification sent: ${student.fullName} -> $staffName');
      return true;
    } catch (e) {
      debugPrint('Error sending notification: $e');
      return false;
    }
  }

  /// Get notifications for a user (stream)
  /// Note: Using client-side sorting to avoid composite index requirement
  Stream<List<AppNotification>> getNotificationsStream(String userId) {
    return _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final notifications = snapshot.docs
              .map((doc) => AppNotification.fromFirestore(doc))
              .toList();
          // Sort client-side to avoid composite index requirement
          notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          // Limit to 50 most recent
          return notifications.take(50).toList();
        });
  }

  /// Get unread notification count (stream)
  /// Note: Using client-side filtering to avoid composite index requirement
  Stream<int> getUnreadCountStream(String userId) {
    return _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          // Filter unread client-side to avoid composite index requirement
          return snapshot.docs
              .map((doc) => AppNotification.fromFirestore(doc))
              .where((n) => !n.isRead)
              .length;
        });
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read for a user
  /// Note: Using client-side filtering to avoid composite index requirement
  Future<void> markAllAsRead(String userId) async {
    try {
      final batch = _firestore.batch();
      final allDocs = await _firestore
          .collection('notifications')
          .where('recipientId', isEqualTo: userId)
          .get();

      // Filter unread client-side
      for (final doc in allDocs.docs) {
        final data = doc.data();
        if (data['isRead'] == false) {
          batch.update(doc.reference, {'isRead': true});
        }
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  /// Delete all notifications for a user
  Future<void> deleteAllNotifications(String userId) async {
    try {
      final batch = _firestore.batch();
      final docs = await _firestore
          .collection('notifications')
          .where('recipientId', isEqualTo: userId)
          .get();

      for (final doc in docs.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error deleting all notifications: $e');
    }
  }

  /// Check if student has recently pinged this staff (to prevent spam)
  /// Note: Using client-side filtering to avoid composite index requirement
  Future<bool> hasRecentlyPinged(String studentId, String staffId) async {
    try {
      final fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5));
      
      // Query by senderId only and filter the rest client-side
      final pings = await _firestore
          .collection('notifications')
          .where('senderId', isEqualTo: studentId)
          .get();

      // Filter client-side for other conditions
      final recentPings = pings.docs.where((doc) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        return data['recipientId'] == staffId &&
               data['type'] == NotificationType.lookingForYou.name &&
               createdAt != null &&
               createdAt.isAfter(fiveMinutesAgo);
      });

      return recentPings.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking recent pings: $e');
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    stopListening();
  }
}
