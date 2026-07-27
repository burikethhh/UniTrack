import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Lightweight service for logging user activity to Firestore.
/// Used for campus safety audit trail (who viewed whom, who pinged whom).
class ActivityLogService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Log an activity event. Fire-and-forget — never blocks the caller.
  void log({
    required String action,
    String? targetId,
    String? details,
  }) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      _firestore.collection('activity_logs').add({
        'actorId': uid,
        'action': action,
        'targetId': targetId,
        'details': details,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) debugPrint('ActivityLog error: $e');
    }
  }

  /// Log when a user views another user's profile
  void logProfileView(String targetUserId) {
    log(action: 'PROFILE_VIEW', targetId: targetUserId);
  }

  /// Log when a user pings a leader/officer
  void logPing(String targetUserId) {
    log(action: 'PING_SENT', targetId: targetUserId);
  }

  /// Log when a user enables location tracking
  void logTrackingEnabled() {
    log(action: 'TRACKING_ENABLED');
  }

  /// Log when a user disables location tracking
  void logTrackingDisabled() {
    log(action: 'TRACKING_DISABLED');
  }

  /// Log when a user opens the map to view leaders
  void logMapView() {
    log(action: 'MAP_VIEWED');
  }

  /// Log when a user searches in the directory
  void logSearch(String query) {
    log(action: 'DIRECTORY_SEARCH', details: query);
  }

  // ── Admin action logging ──────────────────────────────────────────
  // These provide attribution for moderator actions so the admin team
  // can audit who banned/deleted/promoted/broadcast what.

  /// Log when an admin bans a user
  void logBanUser(String targetUserId, {String? reason}) {
    log(action: 'BAN_USER', targetId: targetUserId, details: reason);
  }

  /// Log when an admin unbans a user
  void logUnbanUser(String targetUserId) {
    log(action: 'UNBAN_USER', targetId: targetUserId);
  }

  /// Log when an admin deletes a user
  void logDeleteUser(String targetUserId) {
    log(action: 'DELETE_USER', targetId: targetUserId);
  }

  /// Log when an admin changes a user's role
  void logRoleChange(String targetUserId, String newRole) {
    log(action: 'ROLE_CHANGE', targetId: targetUserId, details: newRole);
  }

  /// Log when an admin sends a broadcast
  void logBroadcast(String audience, int recipientCount) {
    log(action: 'BROADCAST_SENT', details: '$audience ($recipientCount)');
  }
}
