import 'package:cloud_firestore/cloud_firestore.dart';

/// Type of activity being logged, used to pick an icon/color
/// in RecentActivitiesCard.
enum ActivityType {
  sisterRegistered,
  sisterApproved,
  sisterRejected,
  profileUpdated,
  sisterDeleted,
  other,
}

extension ActivityTypeX on ActivityType {
  static ActivityType fromString(String? value) {
    switch (value) {
      case 'sisterRegistered':
        return ActivityType.sisterRegistered;
      case 'sisterApproved':
        return ActivityType.sisterApproved;
      case 'sisterRejected':
        return ActivityType.sisterRejected;
      case 'profileUpdated':
        return ActivityType.profileUpdated;
      case 'sisterDeleted':
        return ActivityType.sisterDeleted;
      default:
        return ActivityType.other;
    }
  }

  String get value => toString().split('.').last;
}

/// Represents a single entry in the 'activities' Firestore
/// collection, used to populate the admin dashboard's
/// RecentActivitiesCard as an audit/event feed.
class ActivityModel {
  final String id;
  final ActivityType type;
  final String description;
  final String? actorUid; // who performed the action (nullable = system)
  final String? actorName;
  final String? targetSisterUid; // which sister this activity relates to
  final String? targetSisterName;
  final DateTime timestamp;

  const ActivityModel({
    required this.id,
    required this.type,
    required this.description,
    this.actorUid,
    this.actorName,
    this.targetSisterUid,
    this.targetSisterName,
    required this.timestamp,
  });

  factory ActivityModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ActivityModel(
      id: doc.id,
      type: ActivityTypeX.fromString(data['type'] as String?),
      description: data['description'] as String? ?? '',
      actorUid: data['actorUid'] as String?,
      actorName: data['actorName'] as String?,
      targetSisterUid: data['targetSisterUid'] as String?,
      targetSisterName: data['targetSisterName'] as String?,
      timestamp:
          (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.value,
      'description': description,
      'actorUid': actorUid,
      'actorName': actorName,
      'targetSisterUid': targetSisterUid,
      'targetSisterName': targetSisterName,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  /// Human-friendly relative time, e.g. "5m ago", "3h ago", "2d ago".
  String get timeAgo {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }
}