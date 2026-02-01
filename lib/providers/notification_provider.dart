import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import '../models/user_model.dart';
import '../services/notification_service.dart';

/// Provider for managing notifications state
class NotificationProvider extends ChangeNotifier {
  final NotificationService _notificationService;
  
  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _error;
  String? _currentUserId;
  
  StreamSubscription? _notificationsSubscription;
  StreamSubscription? _unreadCountSubscription;

  NotificationProvider(this._notificationService);

  // Getters
  List<AppNotification> get notifications => _notifications;
  List<AppNotification> get unreadNotifications => 
      _notifications.where((n) => !n.isRead).toList();
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasUnread => _unreadCount > 0;

  /// Initialize notifications for a user
  Future<void> initialize(String userId) async {
    if (_currentUserId == userId) return;
    
    _currentUserId = userId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Initialize the notification service
      await _notificationService.initialize();
      
      // Start listening for push notifications
      _notificationService.startListening(userId);
      
      // Subscribe to notifications stream
      _notificationsSubscription?.cancel();
      _notificationsSubscription = _notificationService
          .getNotificationsStream(userId)
          .listen(
        (notifications) {
          _notifications = notifications;
          _isLoading = false;
          notifyListeners();
        },
        onError: (e) {
          _error = 'Failed to load notifications';
          _isLoading = false;
          notifyListeners();
        },
      );

      // Subscribe to unread count stream
      _unreadCountSubscription?.cancel();
      _unreadCountSubscription = _notificationService
          .getUnreadCountStream(userId)
          .listen(
        (count) {
          _unreadCount = count;
          notifyListeners();
        },
        onError: (e) {
          debugPrint('Error getting unread count: $e');
        },
      );
    } catch (e) {
      _error = 'Failed to initialize notifications';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Send a "looking for you" ping to a staff member
  Future<bool> pingStaff({
    required UserModel student,
    required String staffId,
    required String staffName,
    String? studentLocation,
  }) async {
    try {
      // Check if recently pinged (spam prevention)
      final hasRecent = await _notificationService.hasRecentlyPinged(
        student.id,
        staffId,
      );
      
      if (hasRecent) {
        _error = 'Please wait 5 minutes before pinging again';
        notifyListeners();
        return false;
      }

      final success = await _notificationService.sendLookingForYouNotification(
        student: student,
        staffId: staffId,
        staffName: staffName,
        studentLocation: studentLocation,
      );

      if (!success) {
        _error = 'Failed to send notification';
        notifyListeners();
      }

      return success;
    } catch (e) {
      _error = 'Failed to send notification';
      notifyListeners();
      return false;
    }
  }

  /// Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    await _notificationService.markAsRead(notificationId);
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    if (_currentUserId != null) {
      await _notificationService.markAllAsRead(_currentUserId!);
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    await _notificationService.deleteNotification(notificationId);
  }

  /// Delete all notifications
  Future<void> deleteAllNotifications() async {
    if (_currentUserId != null) {
      await _notificationService.deleteAllNotifications(_currentUserId!);
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Stop listening and clean up
  void stopListening() {
    _notificationsSubscription?.cancel();
    _unreadCountSubscription?.cancel();
    _notificationService.stopListening();
    _currentUserId = null;
    _notifications = [];
    _unreadCount = 0;
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
