import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/activity_model.dart';
import '../utils/app_constants.dart';

/// Writes and streams entries in the 'activities' Firestore
/// collection — the audit trail shown in RecentActivitiesCard
/// on the admin dashboard. Other services (FirestoreService)
/// call logActivity() whenever a meaningful event happens.
class ActivityService {
  ActivityService._internal();
  static final ActivityService instance = ActivityService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _activitiesRef =>
      _firestore.collection(AppConstants.activitiesCollection);

  /// Logs a new activity entry. The current signed-in user (if
  /// any) is recorded as the actor automatically.
  Future<void> logActivity({
    required ActivityType type,
    required String description,
    String? targetSisterUid,
    String? targetSisterName,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    final activity = ActivityModel(
      id: '', // Firestore assigns this on add()
      type: type,
      description: description,
      actorUid: currentUser?.uid,
      actorName: currentUser?.displayName,
      targetSisterUid: targetSisterUid,
      targetSisterName: targetSisterName,
      timestamp: DateTime.now(),
    );

    await _activitiesRef.add(activity.toMap());
  }

  /// Live stream of the most recent [limit] activities, newest
  /// first — used directly by RecentActivitiesCard.
  Stream<List<ActivityModel>> streamRecentActivities({int limit = 10}) {
    return _activitiesRef
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ActivityModel.fromFirestore(doc))
            .toList());
  }

  /// Deletes activity log entries older than [days] days.
  /// Optional maintenance helper — call from an admin action or
  /// a scheduled Cloud Function if you want automatic cleanup.
  Future<void> pruneOldActivities({int days = 90}) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final snapshot = await _activitiesRef
        .where('timestamp', isLessThan: Timestamp.fromDate(cutoff))
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}