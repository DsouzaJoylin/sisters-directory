import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/sister_model.dart';
import '../utils/app_constants.dart';
import 'activity_service.dart';
import '../models/activity_model.dart';

/// Core CRUD + query layer for the 'sisters' Firestore collection.
/// Admin pages (manage_sisters_page, add_sister_page, reports_page)
/// and the dashboard all go through this service rather than
/// touching Firestore directly, so query logic stays in one place.
///
/// NOTE: SisterModel.fromFirestore is async (it reads the
/// religiousLife/details subcollection to resolve community), so
/// every place below that builds SisterModels from a query snapshot
/// uses Future.wait over the docs instead of a plain synchronous
/// .map(...).toList(). Don't revert these to sync map calls — it
/// won't compile, since fromFirestore returns a Future<SisterModel>.
class FirestoreService {
  FirestoreService._internal();
  static final FirestoreService instance = FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _sistersRef =>
      _firestore.collection(AppConstants.sistersCollection);

  Future<List<SisterModel>> _mapDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return Future.wait(docs.map((doc) => SisterModel.fromFirestore(doc)));
  }

  /// Live stream of all sisters, ordered by full name.
  Stream<List<SisterModel>> streamAllSisters() {
    return _sistersRef
        .orderBy('fullName')
        .snapshots()
        .asyncMap((snapshot) => _mapDocs(snapshot.docs));
  }

  /// Live stream of sisters filtered by status
  /// ('pending' | 'approved' | 'rejected').
  Stream<List<SisterModel>> streamSistersByStatus(String status) {
    return _sistersRef
        .where(AppConstants.fieldStatus, isEqualTo: status)
        .orderBy('fullName')
        .snapshots()
        .asyncMap((snapshot) => _mapDocs(snapshot.docs));
  }

  /// One-time fetch of a single sister by uid. Returns null if
  /// no profile exists yet.
  Future<SisterModel?> getSisterById(String uid) async {
    final doc = await _sistersRef.doc(uid).get();
    if (!doc.exists) return null;
    return SisterModel.fromFirestore(doc);
  }

  /// Creates or fully overwrites a sister's profile document.
  /// Used by add_sister_page (admin manually adding a sister)
  /// and complete_profile_screen (self-registration flow).
  Future<void> saveSister(SisterModel sister, {bool isNew = true}) async {
    await _sistersRef.doc(sister.uid).set(sister.toMap());

    await ActivityService.instance.logActivity(
      type: isNew ? ActivityType.sisterRegistered : ActivityType.profileUpdated,
      description: isNew
          ? '${sister.fullName} joined the directory'
          : '${sister.fullName}\'s profile was updated',
      targetSisterUid: sister.uid,
      targetSisterName: sister.fullName,
    );
  }

  /// Partially updates specific fields on a sister's document
  /// (e.g. editing a single field from manage_sisters_page).
  Future<void> updateSisterFields(
    String uid,
    Map<String, dynamic> fields,
  ) async {
    await _sistersRef.doc(uid).update(fields);
  }

  /// Approves a pending sister profile.
  Future<void> approveSister(String uid, String fullName) async {
    await _sistersRef.doc(uid).update({
      AppConstants.fieldStatus: AppConstants.statusApproved,
    });

    await ActivityService.instance.logActivity(
      type: ActivityType.sisterApproved,
      description: '$fullName\'s profile was approved',
      targetSisterUid: uid,
      targetSisterName: fullName,
    );
  }

  /// Rejects a pending sister profile.
  Future<void> rejectSister(String uid, String fullName) async {
    await _sistersRef.doc(uid).update({
      AppConstants.fieldStatus: AppConstants.statusRejected,
    });

    await ActivityService.instance.logActivity(
      type: ActivityType.sisterRejected,
      description: '$fullName\'s profile was rejected',
      targetSisterUid: uid,
      targetSisterName: fullName,
    );
  }

  /// Deletes a sister's profile entirely.
  Future<void> deleteSister(String uid, String fullName) async {
    await _sistersRef.doc(uid).delete();

    await ActivityService.instance.logActivity(
      type: ActivityType.sisterDeleted,
      description: '$fullName was removed from the directory',
      targetSisterUid: uid,
      targetSisterName: fullName,
    );
  }

  /// Client-side search across name, community, email, and phone.
  /// Firestore doesn't support full-text search natively, so this
  /// fetches all sisters once and filters in memory. Fine for a
  /// directory-sized collection; swap for Algolia/Typesense later
  /// if the member count grows very large.
  Future<List<SisterModel>> searchSisters(String query) async {
    if (query.trim().isEmpty) return [];

    final snapshot = await _sistersRef.get();
    final sisters = await _mapDocs(snapshot.docs);
    final lowerQuery = query.trim().toLowerCase();

    return sisters
        .where((sister) =>
            sister.fullName.toLowerCase().contains(lowerQuery) ||
            sister.community.toLowerCase().contains(lowerQuery) ||
            sister.email.toLowerCase().contains(lowerQuery) ||
            sister.phone.contains(lowerQuery))
        .toList();
  }

  /// Sisters whose birthday falls within the next [days] days,
  /// sorted by how soon the birthday occurs. Used by
  /// UpcomingBirthdaysCard.
  Future<List<SisterModel>> getUpcomingBirthdays({int days = 30}) async {
    final snapshot = await _sistersRef
        .where(AppConstants.fieldStatus, isEqualTo: AppConstants.statusApproved)
        .get();

    final allSisters = await _mapDocs(snapshot.docs);
    final sisters =
        allSisters.where((sister) => sister.hasBirthdayWithin(days)).toList();

    sisters.sort((a, b) {
      final now = DateTime.now();
      DateTime nextBday(SisterModel s) {
        var next = DateTime(now.year, s.dateOfBirth.month, s.dateOfBirth.day);
        if (next.isBefore(DateTime(now.year, now.month, now.day))) {
          next = DateTime(now.year + 1, s.dateOfBirth.month, s.dateOfBirth.day);
        }
        return next;
      }

      return nextBday(a).compareTo(nextBday(b));
    });

    return sisters;
  }
}