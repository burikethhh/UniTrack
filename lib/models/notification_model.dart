import 'package:cloud_firestore/cloud_firestore.dart';

/// Types of notifications
enum NotificationType {
  lookingForYou, // Student is looking for faculty
  locationUpdate, // Faculty location changed
  statusChange, // Faculty status changed
  system, // System notification
  appUpdate, // App update notification
}

/// Push delivery status
enum PushDeliveryStatus {
  pending,    // Queued in Firestore, not yet picked up by dispatcher
  sending,    // Dispatcher is processing this notification
  sent,       // Successfully sent to FCM (accepted by FCM server)
  delivered,  // Confirmed delivered to device (device acked)
  failed,     // FCM rejected (invalid token, etc.)
  opened,     // User tapped the notification
}

/// Notification model for student-faculty communication
class AppNotification {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderPhotoUrl;
  final String recipientId;
  final NotificationType type;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic>? data; // Additional data (e.g., location)

  // Push delivery tracking fields
  final PushDeliveryStatus pushStatus;
  final DateTime? sentAt;
  final DateTime? deliveredAt;
  final DateTime? openedAt;
  final int pushTokenCount; // Number of tokens notification was sent to
  final String? pushError; // Error message if failed
  final List<String>? deliveredTokens; // Tokens that confirmed delivery

  AppNotification({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderPhotoUrl,
    required this.recipientId,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
    this.data,
    this.pushStatus = PushDeliveryStatus.pending,
    this.sentAt,
    this.deliveredAt,
    this.openedAt,
    this.pushTokenCount = 0,
    this.pushError,
    this.deliveredTokens,
  });

  /// Create from Firestore document
  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? 'Unknown',
      senderPhotoUrl: data['senderPhotoUrl'],
      recipientId: data['recipientId'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => NotificationType.system,
      ),
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
      data: data['data'] as Map<String, dynamic>?,
      pushStatus: PushDeliveryStatus.values.firstWhere(
        (e) => e.name == data['pushStatus'],
        orElse: () => PushDeliveryStatus.pending,
      ),
      sentAt: (data['sentAt'] as Timestamp?)?.toDate(),
      deliveredAt: (data['deliveredAt'] as Timestamp?)?.toDate(),
      openedAt: (data['openedAt'] as Timestamp?)?.toDate(),
      pushTokenCount: data['pushTokenCount'] ?? 0,
      pushError: data['pushError'],
      deliveredTokens: data['deliveredTokens'] != null
          ? List<String>.from(data['deliveredTokens'] as List)
          : null,
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderPhotoUrl': senderPhotoUrl,
      'recipientId': recipientId,
      'type': type.name,
      'title': title,
      'message': message,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
      'data': data,
      'pushStatus': pushStatus.name,
      'sentAt': sentAt != null ? Timestamp.fromDate(sentAt!) : null,
      'deliveredAt': deliveredAt != null ? Timestamp.fromDate(deliveredAt!) : null,
      'openedAt': openedAt != null ? Timestamp.fromDate(openedAt!) : null,
      'pushTokenCount': pushTokenCount,
      'pushError': pushError,
      'deliveredTokens': deliveredTokens,
    };
  }

  /// Copy with modifications
  AppNotification copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? senderPhotoUrl,
    String? recipientId,
    NotificationType? type,
    String? title,
    String? message,
    DateTime? createdAt,
    bool? isRead,
    Map<String, dynamic>? data,
    PushDeliveryStatus? pushStatus,
    DateTime? sentAt,
    DateTime? deliveredAt,
    DateTime? openedAt,
    int? pushTokenCount,
    String? pushError,
    List<String>? deliveredTokens,
  }) {
    return AppNotification(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderPhotoUrl: senderPhotoUrl ?? this.senderPhotoUrl,
      recipientId: recipientId ?? this.recipientId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      data: data ?? this.data,
      pushStatus: pushStatus ?? this.pushStatus,
      sentAt: sentAt ?? this.sentAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      openedAt: openedAt ?? this.openedAt,
      pushTokenCount: pushTokenCount ?? this.pushTokenCount,
      pushError: pushError ?? this.pushError,
      deliveredTokens: deliveredTokens ?? this.deliveredTokens,
    );
  }

  /// Get time ago text
  String get timeAgoText {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }
}
