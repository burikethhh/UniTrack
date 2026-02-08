import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart' show notificationNavigatorKey;

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔔 Background message received: ${message.messageId}');
  // Handle background message
}

/// Service for managing push notifications via Firebase Cloud Messaging
class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  // Lazy init — avoid accessing platform-specific instances on web
  late final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  late final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  
  String? _fcmToken;
  String? get fcmToken => _fcmToken;
  
  // Notification channel for Android (lazy to avoid web crash)
  static AndroidNotificationChannel get _channel => const AndroidNotificationChannel(
    'unitrack_notifications',
    'UniTrack Notifications',
    description: 'Notifications for faculty updates and alerts',
    importance: Importance.high,
    enableVibration: true,
    playSound: true,
  );

  /// Initialize the push notification service
  Future<void> initialize() async {
    try {
      // Request permissions (works on both web and mobile)
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
      );

      debugPrint('📱 FCM Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        await _setupFCM();
        // Only init local notifications on mobile — web uses in-app overlays
        if (!kIsWeb) {
          await _initializeLocalNotifications();
        }
        _setupMessageHandlers();
      }
    } catch (e) {
      debugPrint('❌ Error initializing push notifications: $e');
    }
  }

  Future<void> _setupFCM() async {
    // Get FCM token (web uses VAPID key)
    try {
      if (kIsWeb) {
        // For web, getToken can work without VAPID key if Firebase config is correct
        _fcmToken = await _fcm.getToken(
          vapidKey: null, // Uses Firebase project's default VAPID key
        );
      } else {
        _fcmToken = await _fcm.getToken();
      }
      debugPrint('🔑 FCM Token: $_fcmToken');
    } catch (e) {
      debugPrint('⚠️ FCM getToken error (non-fatal): $e');
    }

    // Listen for token refresh
    _fcm.onTokenRefresh.listen((newToken) {
      debugPrint('🔄 FCM Token refreshed: $newToken');
      _fcmToken = newToken;
      _saveTokenToFirestore(newToken);
    });

    // Set background message handler (mobile only — web uses service worker)
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }
  }

  Future<void> _initializeLocalNotifications() async {
    // Android initialization
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS initialization
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

    // Create notification channel for Android
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  void _setupMessageHandlers() {
    // Handle foreground messages
    _foregroundSubscription = FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle when app is opened from notification
    _messageOpenedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Check for initial message (app opened from terminated state)
    _checkInitialMessage();
  }

  Future<void> _checkInitialMessage() async {
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('📬 App opened from terminated state via notification');
      _handleNotificationData(initialMessage.data);
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📬 Foreground message: ${message.notification?.title}');
    
    final notification = message.notification;

    if (notification == null) return;

    // On web, show in-app overlay notification
    if (kIsWeb) {
      _showWebOverlayNotification(
        title: notification.title ?? 'UniTrack',
        body: notification.body ?? '',
      );
      return;
    }
    
    final android = message.notification?.android;

    // Show local notification when app is in foreground (mobile)
    _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: android?.smallIcon ?? '@mipmap/ic_launcher',
            color: const Color(0xFF3EB489),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(message.data),
      );
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('📬 App opened via notification: ${message.notification?.title}');
    _handleNotificationData(message.data);
  }

  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        _handleNotificationData(data);
      } catch (e) {
        debugPrint('Error parsing notification payload: $e');
      }
    }
  }

  void _handleNotificationData(Map<String, dynamic> data) {
    // Handle notification navigation based on type
    final type = data['type'] as String?;
    final targetId = data['targetId'] as String?;

    debugPrint('📌 Handling notification: type=$type, targetId=$targetId');

    // TODO: Implement navigation based on notification type
    // Examples:
    // - 'faculty_available': Navigate to faculty detail
    // - 'location_update': Navigate to map
    // - 'announcement': Navigate to announcements
  }

  /// Save FCM token to Firestore for the current user
  Future<void> saveTokenForUser(String userId) async {
    if (_fcmToken == null) return;
    
    try {
      await _firestore.collection('users').doc(userId).set({
        'fcmTokens': FieldValue.arrayUnion([_fcmToken]),
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      // Also save locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', _fcmToken!);
      
      debugPrint('✅ FCM token saved for user: $userId');
    } catch (e) {
      debugPrint('❌ Error saving FCM token: $e');
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('current_user_id');
    
    if (userId != null) {
      await saveTokenForUser(userId);
    }
  }

  /// Remove FCM token when user logs out
  Future<void> removeTokenForUser(String userId) async {
    if (_fcmToken == null) return;
    
    try {
      await _firestore.collection('users').doc(userId).set({
        'fcmTokens': FieldValue.arrayRemove([_fcmToken]),
      }, SetOptions(merge: true));
      debugPrint('✅ FCM token removed for user: $userId');
    } catch (e) {
      debugPrint('❌ Error removing FCM token: $e');
    }
  }

  /// Subscribe to a topic for receiving group notifications
  Future<void> subscribeToTopic(String topic) async {
    if (kIsWeb) return; // Topics not supported on web
    try {
      await _fcm.subscribeToTopic(topic);
      debugPrint('✅ Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('❌ Error subscribing to topic $topic: $e');
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    if (kIsWeb) return; // Topics not supported on web
    try {
      await _fcm.unsubscribeFromTopic(topic);
      debugPrint('✅ Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('❌ Error unsubscribing from topic $topic: $e');
    }
  }

  /// Subscribe to faculty-specific notifications
  Future<void> subscribeToFacultyUpdates(String facultyId) async {
    await subscribeToTopic('faculty_$facultyId');
  }

  /// Unsubscribe from faculty-specific notifications
  Future<void> unsubscribeFromFacultyUpdates(String facultyId) async {
    await unsubscribeFromTopic('faculty_$facultyId');
  }

  /// Subscribe to campus-specific notifications
  Future<void> subscribeToCampusUpdates(String campusId) async {
    await subscribeToTopic('campus_$campusId');
  }

  /// Subscribe to department notifications
  Future<void> subscribeToDepartmentUpdates(String department) async {
    // Sanitize department name for topic
    final sanitized = department.replaceAll(RegExp(r'[^a-zA-Z0-9-_.~%]'), '_');
    await subscribeToTopic('dept_$sanitized');
  }

  /// Show a local notification (for testing or manual triggers)
  Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    if (kIsWeb) {
      _showWebOverlayNotification(title: title, body: body);
      return;
    }
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF3EB489),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: data != null ? jsonEncode(data) : null,
    );
  }

  /// Get notification settings status
  Future<NotificationSettings> getNotificationSettings() async {
    return await _fcm.getNotificationSettings();
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    final settings = await getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
           settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Clear all pending notifications
  Future<void> clearAllNotifications() async {
    if (kIsWeb) return;
    await _localNotifications.cancelAll();
  }

  /// Show an in-app overlay notification for web
  void _showWebOverlayNotification({required String title, required String body}) {
    // Import the navigator key from notification_service.dart
    final overlayState = notificationNavigatorKey.currentState?.overlay;
    if (overlayState == null) {
      debugPrint('📱 Web notification (no overlay): $title - $body');
      return;
    }

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFF1565C0),
          child: InkWell(
            onTap: () { if (entry.mounted) entry.remove(); },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.notifications, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(body, style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
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
    );
    overlayState.insert(entry);
    Future.delayed(const Duration(seconds: 4), () {
      if (entry.mounted) entry.remove();
    });
  }

  /// Dispose resources
  void dispose() {
    _foregroundSubscription?.cancel();
    _messageOpenedSubscription?.cancel();
  }
}
