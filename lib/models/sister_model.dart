import 'package:cloud_firestore/cloud_firestore.dart';

/// NOTE ON SCHEMA (read this before touching age/community logic):
///
/// Two different sources feed the 'sisters' collection:
/// - AdminAddSisterScreen writes 'dob' (dd/mm/yyyy string) plus
///   'birthMonth'/'birthDay'/'birthYear' ints, and stores community as
///   'currentCommunity' one level down in the religiousLife/details
///   subcollection.
/// - Older/self-registered sisters may only have a legacy top-level
///   'dateOfBirth' Timestamp and/or a legacy top-level 'community'
///   string.
///
/// This model now checks the AdminAddSisterScreen-style fields FIRST
/// (matching DashboardService's logic, which is the canonical source
/// of truth per the "Option A" schema decision), then falls back to
/// the legacy fields so older records don't silently break. Do NOT
/// revert to reading only 'dateOfBirth'/'community' — that was the
/// bug that caused every admin-added sister to show age 56 (the
/// DateTime(1970,1,1) fallback) and an empty community.
class SisterModel {
  final String uid;
  final String fullName;
  final String email;
  final String phone;
  final String community;
  final String address;
  final String occupation;
  final DateTime dateOfBirth;
  final String maritalStatus;
  final String status;
  final String? photoUrl; // Firebase Storage download URL, null if no photo
  // Base64-encoded photo, saved by AdminAddSisterScreen under
  // documents.photoBase64. This is the field that's actually populated
  // today — photoUrl is reserved for a future Storage-URL-based flow.
  // SisterAvatar prefers this over photoUrl when both are present.
  final String? photoBase64;
  final DateTime? createdAt;

  const SisterModel({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.community,
    required this.address,
    required this.occupation,
    required this.dateOfBirth,
    required this.maritalStatus,
    required this.status,
    this.photoUrl,
    this.photoBase64,
    this.createdAt,
  });

  int get age {
    final now = DateTime.now();
    int years = now.year - dateOfBirth.year;
    final hasHadBirthdayThisYear = (now.month > dateOfBirth.month) ||
        (now.month == dateOfBirth.month && now.day >= dateOfBirth.day);
    if (!hasHadBirthdayThisYear) years--;
    return years;
  }

  bool hasBirthdayWithin(int days) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var nextBirthday =
        DateTime(today.year, dateOfBirth.month, dateOfBirth.day);
    if (nextBirthday.isBefore(today)) {
      nextBirthday =
          DateTime(today.year + 1, dateOfBirth.month, dateOfBirth.day);
    }
    final diff = nextBirthday.difference(today).inDays;
    return diff >= 0 && diff <= days;
  }

  static String? _photoBase64FromData(Map<String, dynamic> data) {
    final documents = data['documents'];
    if (documents is Map) {
      final b64 = documents['photoBase64'];
      if (b64 is String && b64.isNotEmpty) return b64;
    }
    return null;
  }

  /// Parses 'dob' stored as dd/mm/yyyy. Returns (day, month, year) or
  /// null if unparseable. Mirrors DashboardService._parseDob — keep
  /// these in sync if the dob format ever changes.
  static (int, int, int)? _parseDob(String? dobStr) {
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

  /// Resolves a sister's date of birth, preferring the fields
  /// AdminAddSisterScreen writes (birthYear/birthMonth/birthDay ints,
  /// then the 'dob' string), then falling back to a legacy top-level
  /// 'dateOfBirth' Timestamp for older self-registered records. Only
  /// falls back to the Unix epoch if genuinely nothing is available —
  /// that fallback previously masqueraded as a real age (56, in 2026)
  /// for every sister missing these fields, which is the bug this
  /// method fixes.
  static DateTime _resolveDateOfBirth(Map<String, dynamic> data) {
    final year = data['birthYear'];
    final month = data['birthMonth'];
    final day = data['birthDay'];
    if (year is int && month is int && day is int) {
      return DateTime(year, month, day);
    }

    final parsedDob = _parseDob(data['dob'] as String?);
    if (parsedDob != null) {
      final (parsedDay, parsedMonth, parsedYear) = parsedDob;
      return DateTime(parsedYear, parsedMonth, parsedDay);
    }

    final legacyTimestamp = data['dateOfBirth'];
    if (legacyTimestamp is Timestamp) {
      return legacyTimestamp.toDate();
    }

    return DateTime(1970, 1, 1);
  }

  /// Resolves a sister's community, preferring 'currentCommunity' from
  /// the religiousLife/details subcollection (what AdminAddSisterScreen
  /// and the dashboard charts use), falling back to a legacy top-level
  /// 'community' field for older records that have one.
  static Future<String> _resolveCommunity(
    DocumentSnapshot<Map<String, dynamic>> doc,
    Map<String, dynamic> data,
  ) async {
    try {
      final religiousLifeDoc =
          await doc.reference.collection('religiousLife').doc('details').get();
      final currentCommunity =
          religiousLifeDoc.data()?['currentCommunity'] as String?;
      if (currentCommunity != null && currentCommunity.trim().isNotEmpty) {
        return currentCommunity.trim();
      }
    } catch (_) {
      // Fall through to the legacy field below if the subcollection
      // read fails for any reason (e.g. missing permissions on an
      // older record).
    }

    return (data['community'] as String?)?.trim() ?? '';
  }

  /// Builds a SisterModel from a Firestore doc, resolving date of
  /// birth and community per the schema notes above. This is async
  /// because community requires an extra subcollection read — every
  /// caller (FirestoreService streams/fetches) awaits this per doc.
  static Future<SisterModel> fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data() ?? {};
    final community = await _resolveCommunity(doc, data);

    return SisterModel(
      uid: data['uid'] as String? ?? doc.id,
      fullName: data['fullName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? data['mobileNumber'] as String? ?? '',
      community: community,
      address: data['address'] as String? ?? '',
      occupation: data['occupation'] as String? ?? '',
      dateOfBirth: _resolveDateOfBirth(data),
      maritalStatus: data['maritalStatus'] as String? ?? 'Single',
      status: data['status'] as String? ?? 'approved',
      photoUrl: data['photoUrl'] as String?,
      photoBase64: _photoBase64FromData(data),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  /// NOTE: unlike fromFirestore, this has no DocumentReference to read
  /// the religiousLife/details subcollection from, so it can only ever
  /// resolve community from the legacy top-level 'community' field.
  /// Prefer fromFirestore wherever a DocumentSnapshot is available.
  factory SisterModel.fromMap(String id, Map<String, dynamic> data) {
    return SisterModel(
      uid: data['uid'] as String? ?? id,
      fullName: data['fullName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? data['mobileNumber'] as String? ?? '',
      community: (data['community'] as String?)?.trim() ?? '',
      address: data['address'] as String? ?? '',
      occupation: data['occupation'] as String? ?? '',
      dateOfBirth: _resolveDateOfBirth(data),
      maritalStatus: data['maritalStatus'] as String? ?? 'Single',
      status: data['status'] as String? ?? 'approved',
      photoUrl: data['photoUrl'] as String?,
      photoBase64: _photoBase64FromData(data),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'community': community,
      'address': address,
      'occupation': occupation,
      'dateOfBirth': Timestamp.fromDate(dateOfBirth),
      'maritalStatus': maritalStatus,
      'status': status,
      'photoUrl': photoUrl,
      'createdAt':
          createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  SisterModel copyWith({
    String? fullName,
    String? phone,
    String? community,
    String? address,
    String? occupation,
    DateTime? dateOfBirth,
    String? maritalStatus,
    String? status,
    String? photoUrl,
    String? photoBase64,
  }) {
    return SisterModel(
      uid: uid,
      fullName: fullName ?? this.fullName,
      email: email,
      phone: phone ?? this.phone,
      community: community ?? this.community,
      address: address ?? this.address,
      occupation: occupation ?? this.occupation,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      status: status ?? this.status,
      photoUrl: photoUrl ?? this.photoUrl,
      photoBase64: photoBase64 ?? this.photoBase64,
      createdAt: createdAt,
    );
  }
}