import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/dashboard_stats.dart';

/// A sister with an upcoming birthday, for the Upcoming Birthdays card.
class UpcomingBirthday {
  final String uid;
  final String fullName;
  final DateTime nextBirthday; // next occurrence, this year or next
  final String? photoBase64; // from documents.photoBase64, if set

  const UpcomingBirthday({
    required this.uid,
    required this.fullName,
    required this.nextBirthday,
    this.photoBase64,
  });
}

/// Computes dashboard stats directly from the real 'sisters' schema.
///
/// IMPORTANT — schema notes:
/// - Birth date is stored as free text 'dob' (dd/mm/yyyy), with
///   'birthMonth'/'birthDay'/'birthYear' ints only present on sisters
///   saved by the current PersonalInformationScreen / AdminAddSisterScreen.
///   Older records fall back to parsing 'dob'.
/// - 'currentCommunity' is NOT a top-level field on the sister doc —
///   it lives in the sisters/{uid}/religiousLife/details subcollection.
///   Computing community distribution therefore requires one extra
///   read per sister; fine for a congregation-sized directory, but
///   worth knowing if the sister count grows very large.
///
/// NOTE: DashboardStats itself now lives only in
/// '../models/dashboard_stats.dart'. This file used to define its own
/// duplicate DashboardStats class, which caused "imported from both"
/// ambiguous-import errors and Stream<DashboardStats> type mismatches
/// anywhere both files were imported together. Don't redefine it here
/// again — always import and reuse the model class.
class DashboardService {
  DashboardService._internal();
  static final DashboardService instance = DashboardService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _sistersRef =>
      _firestore.collection('sisters');

  /// Live stream of dashboard stats. Re-fetches community data
  /// (one read per sister) whenever the sisters collection changes.
  Stream<DashboardStats> streamDashboardStats() {
    return _sistersRef.snapshots().asyncMap(_computeStats);
  }

  /// One-time fetch, e.g. for reports.
  Future<DashboardStats> fetchDashboardStats() async {
    final snapshot = await _sistersRef.get();
    return _computeStats(snapshot);
  }

  Future<DashboardStats> _computeStats(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    final now = DateTime.now();
    int pending = 0;
    int approved = 0;
    int rejected = 0;
    int newThisMonth = 0;

    final ageDistribution = <String, int>{
      for (final bracket in DashboardStats.ageBrackets) bracket: 0,
    };

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final status = (data['status'] as String?) ?? 'approved';
      if (status == 'pending') {
        pending++;
      } else if (status == 'rejected') {
        rejected++;
      } else {
        approved++;
      }

      final createdAt = data['createdAt'];
      if (createdAt is Timestamp) {
        final created = createdAt.toDate();
        if (created.year == now.year && created.month == now.month) {
          newThisMonth++;
        }
      }

      final age = _extractAge(data, now);
      if (age != null) {
        final bracket = DashboardStats.bracketForAge(age);
        ageDistribution[bracket] = (ageDistribution[bracket] ?? 0) + 1;
      }
    }

    // Community distribution needs a subcollection read per sister,
    // since 'currentCommunity' lives in religiousLife/details, not on
    // the main sister document. Run these in parallel.
    final communityFutures = snapshot.docs.map((doc) async {
      final religiousLifeDoc = await doc.reference
          .collection('religiousLife')
          .doc('details')
          .get();
      final community = religiousLifeDoc.data()?['currentCommunity'] as String?;
      return community?.trim();
    });

    final communities = await Future.wait(communityFutures);
    final communityDistribution = <String, int>{};
    for (final community in communities) {
      if (community == null || community.isEmpty) continue;
      communityDistribution[community] =
          (communityDistribution[community] ?? 0) + 1;
    }

    return DashboardStats(
      totalSisters: snapshot.docs.length,
      pendingProfiles: pending,
      approvedProfiles: approved,
      rejectedProfiles: rejected,
      newThisMonth: newThisMonth,
      ageDistribution: ageDistribution,
      communityDistribution: communityDistribution,
    );
  }

  /// Sisters whose birthday falls within the next [days] days,
  /// soonest first. Uses birthMonth/birthDay when present, otherwise
  /// falls back to parsing the 'dob' string (dd/mm/yyyy).
  Future<List<UpcomingBirthday>> getUpcomingBirthdays({int days = 30}) async {
    final snapshot = await _sistersRef.get();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final results = <UpcomingBirthday>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final birthday = _extractMonthDay(data);
      if (birthday == null) continue;

      var next = DateTime(today.year, birthday.$1, birthday.$2);
      if (next.isBefore(today)) {
        next = DateTime(today.year + 1, birthday.$1, birthday.$2);
      }

      final diff = next.difference(today).inDays;
      if (diff >= 0 && diff <= days) {
        final documents = data['documents'];
        final photoBase64 = documents is Map
            ? documents['photoBase64'] as String?
            : null;

        results.add(UpcomingBirthday(
          uid: doc.id,
          fullName: (data['fullName'] as String?) ?? '',
          nextBirthday: next,
          photoBase64: (photoBase64 != null && photoBase64.isNotEmpty)
              ? photoBase64
              : null,
        ));
      }
    }

    results.sort((a, b) => a.nextBirthday.compareTo(b.nextBirthday));
    return results;
  }

  /// Returns (month, day) if derivable, else null. Tries
  /// birthMonth/birthDay first, falls back to parsing 'dob' as
  /// dd/mm/yyyy.
  (int, int)? _extractMonthDay(Map<String, dynamic> data) {
    final month = data['birthMonth'];
    final day = data['birthDay'];
    if (month is int && day is int && month >= 1 && month <= 12 && day >= 1 && day <= 31) {
      return (month, day);
    }

    final parsed = _parseDob(data['dob'] as String?);
    if (parsed != null) return (parsed.$2, parsed.$1); // (day, month, year) -> (month, day)

    return null;
  }

  /// Returns age in whole years if derivable, else null. Tries
  /// birthYear first, falls back to parsing 'dob'.
  int? _extractAge(Map<String, dynamic> data, DateTime now) {
    final year = data['birthYear'];
    final month = data['birthMonth'];
    final day = data['birthDay'];

    if (year is int && month is int && day is int) {
      return _ageFrom(year, month, day, now);
    }

    final parsed = _parseDob(data['dob'] as String?);
    if (parsed != null) {
      final (parsedDay, parsedMonth, parsedYear) = parsed;
      return _ageFrom(parsedYear, parsedMonth, parsedDay, now);
    }

    return null;
  }

  int _ageFrom(int year, int month, int day, DateTime now) {
    int age = now.year - year;
    final hasHadBirthdayThisYear =
        (now.month > month) || (now.month == month && now.day >= day);
    if (!hasHadBirthdayThisYear) age--;
    return age;
  }

  /// Parses 'dob' stored as dd/mm/yyyy. Returns (day, month, year) or
  /// null if unparseable.
  (int, int, int)? _parseDob(String? dobStr) {
    if (dobStr == null || dobStr.trim().isEmpty) return null;
    final parts = dobStr.trim().split('/');
    if (parts.length != 3) return null;

    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);

    if (day == null || month == null || year == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;

    return (day, month, year);
  }
}