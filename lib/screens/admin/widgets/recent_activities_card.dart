import 'package:flutter/material.dart';

import '../../../models/activity_model.dart';
import '../../../services/activity_service.dart';
import '../../../utils/app_colors.dart';
import 'dashboard_card.dart';

/// Live feed of recent admin/system activities (registrations,
/// approvals, edits, deletions), streamed from ActivityService.
class RecentActivitiesCard extends StatelessWidget {
  const RecentActivitiesCard({super.key, this.limit = 8});

  final int limit;

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      title: 'Recent Activity',
      child: StreamBuilder<List<ActivityModel>>(
        stream: ActivityService.instance.streamRecentActivities(limit: limit),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );
          }

          // FIXED: previously any stream error fell through to
          // `snapshot.data ?? []`, which silently rendered "No recent
          // activity yet." even when the real cause was a Firestore
          // error (e.g. a missing composite index for the orderBy+limit
          // query, or a permission-denied). Surface it instead so it's
          // actually visible/debuggable.
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableText(
                      'Could not load recent activity:\n${snapshot.error}',
                      style: const TextStyle(fontSize: 12, color: AppColors.error),
                    ),
                  ),
                ],
              ),
            );
          }

          final activities = snapshot.data ?? [];

          if (activities.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No recent activity yet.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activities.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.divider),
            itemBuilder: (context, index) {
              final activity = activities[index];
              return _buildActivityTile(activity);
            },
          );
        },
      ),
    );
  }

  Widget _buildActivityTile(ActivityModel activity) {
    final visuals = _visualsForType(activity.type);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: visuals.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(visuals.icon, size: 16, color: visuals.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.description,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  activity.timeAgo,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ({IconData icon, Color color}) _visualsForType(ActivityType type) {
    switch (type) {
      case ActivityType.sisterRegistered:
        return (icon: Icons.person_add_alt_1, color: AppColors.info);
      case ActivityType.sisterApproved:
        return (icon: Icons.check_circle_outline, color: AppColors.success);
      case ActivityType.sisterRejected:
        return (icon: Icons.cancel_outlined, color: AppColors.error);
      case ActivityType.profileUpdated:
        return (icon: Icons.edit_outlined, color: AppColors.secondaryDark);
      case ActivityType.sisterDeleted:
        return (icon: Icons.delete_outline, color: AppColors.error);
      case ActivityType.other:
        return (icon: Icons.info_outline, color: AppColors.textSecondary);
    }
  }
}