import 'package:cloud_firestore/cloud_firestore.dart';
import 'activity_log_service.dart';

/// Service responsible for sending broadcast notifications to users.
///
/// Encapsulates Firestore chunking logic so dialog/UI code can stay thin.
class BroadcastService {
  BroadcastService._();

  static final BroadcastService instance = BroadcastService._();

  /// Firestore batch write limit is 500 operations. Use 499 to be safe.
  static const int _chunkSize = 499;

  /// Sends a broadcast notification to [audienceIds].
  ///
  /// [title] and [body] are the notification text. [audienceIds] is the list
  /// of user IDs that should receive the notification. [type] is stored in
  /// the notification's `type` field; the `data.source` field is set to
  /// 'admin_broadcast' and `data.audience` is set to [audienceLabel].
  ///
  /// Returns the number of notifications written.
  Future<int> sendBroadcast({
    required String title,
    required String body,
    required List<String> audienceIds,
    String type = 'admin_broadcast',
    String senderId = 'system',
    String senderName = 'ISKSULARS TRACK Admin',
    String? audienceLabel,
  }) async {
    final firestore = FirebaseFirestore.instance;
    int sentCount = 0;

    for (int i = 0; i < audienceIds.length; i += _chunkSize) {
      final batch = firestore.batch();
      final chunk = audienceIds.skip(i).take(_chunkSize);
      for (final recipientId in chunk) {
        final notifRef = firestore.collection('notifications').doc();
        batch.set(notifRef, {
          'senderId': senderId,
          'senderName': senderName,
          'senderPhotoUrl': null,
          'recipientId': recipientId,
          'type': 'system',
          'title': title,
          'message': body,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
          'data': {
            'source': type,
            'audience': audienceLabel,
          },
        });
        sentCount++;
      }
      await batch.commit();
    }

    return sentCount;
  }

  /// Convenience: fetch the user IDs matching the given filter and send a
  /// broadcast to them.
  ///
  /// [filter] is one of: 'all', 'students', 'admins', 'campus', 'department'.
  /// For 'campus' pass [campus]; for 'department' pass [department].
  Future<int> sendBroadcastToFilter({
    required String title,
    required String body,
    required String filter,
    String? campus,
    String? department,
  }) async {
    final firestore = FirebaseFirestore.instance;
    Query<Map<String, dynamic>> query = firestore.collection('users');

    switch (filter) {
      case 'students':
        query = query.where('role', isEqualTo: 'student');
        break;
      case 'studentLeaders':
        query = query.where('role', isEqualTo: 'studentleader');
        break;
      case 'orgOfficers':
        query = query.where('role', isEqualTo: 'organizationofficer');
        break;
      case 'leaders':
        query = query.where('role',
            whereIn: ['studentleader', 'organizationofficer']);
        break;
      case 'admins':
        query = query.where('role', isEqualTo: 'admin');
        break;
      case 'campus':
        query = query.where('campusId', isEqualTo: campus);
        break;
      case 'department':
        query = query.where('department', isEqualTo: department);
        break;
    }

    final users = await query.limit(5000).get();
    final ids = users.docs.map((d) => d.id).toList();

    final count = await sendBroadcast(
      title: title,
      body: body,
      audienceIds: ids,
      audienceLabel: filter,
    );

    ActivityLogService().logBroadcast(filter, count);
    return count;
  }
}
