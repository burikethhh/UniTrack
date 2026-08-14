import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/notification_model.dart';
import '../models/user_model.dart';
import '../screens/staff_leader/notifications_screen.dart';

/// Global navigator key for showing in-app notifications on web
final GlobalKey<NavigatorState> notificationNavigatorKey =
    GlobalKey<NavigatorState>();

/// Service for handling notifications between students and faculty
class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Lazy init — FlutterLocalNotificationsPlugin has no web implementation
  late final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription? _notificationSubscription;

  /// Initialize local notifications
  Future<void> initialize() async {
    // On web, we use in-app overlay notifications instead
    if (kIsWeb) {
      if (kDebugMode) debugPrint('📱 Using in-app notifications for web');
      return;
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
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
    if (kDebugMode) debugPrint('Notification tapped: ${response.payload}');
    // Can navigate to specific screen based on payload
  }

  /// Start listening for notifications for a specific user
  /// Note: Using client-side filtering to avoid composite index requirement
  void startListening(String userId) {
    _notificationSubscription?.cancel();

    bool isFirstSnapshot = true;

    _notificationSubscription = _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .listen(
          (snapshot) {
            // On the first snapshot, ALL existing docs come as 'added'.
            // Skip local notifications for those — only notify on truly new docs.
            if (isFirstSnapshot) {
              isFirstSnapshot = false;
              return;
            }

            for (final change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added) {
                final notification = AppNotification.fromFirestore(change.doc);
                // Only show local notification for unread notifications
                if (!notification.isRead) {
                  if (notification.type == NotificationType.appUpdate) {
                    if (kDebugMode) debugPrint('📢 App update notification received: ${notification.title}');
                  }
                  _showLocalNotification(notification);
                }
              }
            }
          },
          onError: (e) {
            if (kDebugMode) debugPrint('Error listening to notifications: $e');
          },
        );
  }

  /// Stop listening for notifications
  void stopListening() {
    _notificationSubscription?.cancel();
    _notificationSubscription = null;
  }

  /// Show a local notification
  Future<void> _showLocalNotification(AppNotification notification) async {
    // On web, show an in-app overlay notification
    if (kIsWeb) {
      _showWebNotification(notification);
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'unitrack_notifications',
      'ISKSULARS TRACK Notifications',
      channelDescription: 'Notifications for ISKSULARS TRACK app',
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

  /// Send a "looking for you" notification from student to faculty
  Future<bool> sendLookingForYouNotification({
    required UserModel student,
    required String recipientId,
    required String recipientName,
    String? studentLocation,
  }) async {
    try {
      // Fetch recipient's notification preferences
      final recipientDoc = await _firestore.collection('users').doc(recipientId).get();
      if (!recipientDoc.exists) return false;
      
      final recipientData = recipientDoc.data()!;
      final prefs = NotificationPreferences.fromMap(
        recipientData['notificationPreferences'] as Map<String, dynamic>?,
      );

      // Check if recipient wants to receive "looking for you" notifications
      if (!prefs.shouldReceivePush(NotificationType.lookingForYou)) {
        if (kDebugMode) debugPrint('📢 Notification blocked by user preferences: $recipientId');
        return false;
      }

      final notification = AppNotification(
        id: '', // Will be set by Firestore
        senderId: student.id,
        senderName: student.fullName,
        senderPhotoUrl: student.photoUrl,
        recipientId: recipientId,
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

      await _firestore
          .collection('notifications')
          .add(notification.toFirestore());

      if (kDebugMode) debugPrint('📢 Notification sent: ${student.fullName} -> $recipientName');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Error sending notification: $e');
      return false;
    }
  }

  /// Get notifications for a user (stream)
  /// Uses composite index: recipientId ASC, createdAt DESC
  Stream<List<AppNotification>> getNotificationsStream(String userId) {
    return _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AppNotification.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get unread notification count (stream)
  /// Server-side filter avoids downloading all docs just to count
  Stream<int> getUnreadCountStream(String userId) {
    return _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).set({
        'isRead': true,
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('Error marking notification as read: $e');
    }
  }

  /// Mark notification as opened (user tapped/seen it)
  /// Also marks as read and updates push delivery status
  Future<void> markAsOpened(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).set({
        'isRead': true,
        'openedAt': FieldValue.serverTimestamp(),
        'pushStatus': 'opened',
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('Error marking notification as opened: $e');
    }
  }

  /// Mark all notifications as read for a user
  /// Uses composite index: recipientId ASC, isRead ASC
  Future<void> markAllAsRead(String userId) async {
    try {
      final unreadDocs = await _firestore
          .collection('notifications')
          .where('recipientId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      // Batch in chunks of 499 (Firestore limit is 500)
      for (int i = 0; i < unreadDocs.docs.length; i += 499) {
        final batch = _firestore.batch();
        final chunk = unreadDocs.docs.skip(i).take(499);
        for (final doc in chunk) {
          batch.set(doc.reference, {'isRead': true}, SetOptions(merge: true));
        }
        await batch.commit();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error marking all notifications as read: $e');
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
    } catch (e) {
      if (kDebugMode) debugPrint('Error deleting notification: $e');
    }
  }

  /// Delete all notifications for a user (paginated to avoid memory spikes)
  Future<void> deleteAllNotifications(String userId) async {
    try {
      QuerySnapshot<Map<String, dynamic>> page;
      do {
        page = await _firestore
            .collection('notifications')
            .where('recipientId', isEqualTo: userId)
            .limit(499)
            .get();

        if (page.docs.isEmpty) break;

        final batch = _firestore.batch();
        for (final doc in page.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      } while (page.docs.length == 499);
    } catch (e) {
      if (kDebugMode) debugPrint('Error deleting all notifications: $e');
    }
  }

  /// Check if student has recently pinged this recipient (to prevent spam)
  /// Uses composite index: senderId ASC, recipientId ASC, type ASC, createdAt ASC
  Future<bool> hasRecentlyPinged(String studentId, String recipientId) async {
    try {
      final fiveMinutesAgo = DateTime.now().subtract(
        const Duration(minutes: 5),
      );

      final pings = await _firestore
          .collection('notifications')
          .where('senderId', isEqualTo: studentId)
          .where('recipientId', isEqualTo: recipientId)
          .where('type', isEqualTo: NotificationType.lookingForYou.name)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(fiveMinutesAgo))
          .limit(1)
          .get();

      return pings.docs.isNotEmpty;
    } catch (e) {
      if (kDebugMode) debugPrint('Error checking recent pings: $e');
      return false;
    }
  }

  /// Show a notification toast/alert (public for provider to call)
  void showNotificationAlert(AppNotification notification) {
    _showLocalNotification(notification);
  }

  /// Show in-app overlay notification for web platform
  void _showWebNotification(AppNotification notification) {
    // Use an OverlayEntry for a toast-style notification
    final overlayState = notificationNavigatorKey.currentState?.overlay;
    if (overlayState == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _WebNotificationOverlay(
        title: notification.title,
        message: notification.message,
        onDismiss: () => entry.remove(),
        onTap: () {
          entry.remove();
          notificationNavigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          );
        },
      ),
    );
    overlayState.insert(entry);

    // Auto-dismiss after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (entry.mounted) entry.remove();
    });
  }

  /// Dispose resources
  void dispose() {
    stopListening();
  }
}

/// Web notification overlay widget — shows a Material toast at the top
class _WebNotificationOverlay extends StatefulWidget {
  final String title;
  final String message;
  final VoidCallback onDismiss;
  final VoidCallback? onTap;

  const _WebNotificationOverlay({
    required this.title,
    required this.message,
    required this.onDismiss,
    this.onTap,
  });

  @override
  State<_WebNotificationOverlay> createState() =>
      _WebNotificationOverlayState();
}

class _WebNotificationOverlayState extends State<_WebNotificationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_controller);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFF2E7D32),
            child: InkWell(
              onTap: widget.onTap ?? widget.onDismiss,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.notifications_active,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.message,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.close, color: Colors.white54, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
