import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../models/activity_model.dart';
import '../../../services/activity_service.dart';
import '../../../utils/app_colors.dart';
import '../../../widgets/sister_avatar.dart';
import 'dashboard_card.dart';

/// Live list of sisters awaiting profile approval, with inline
/// Approve/Reject actions. Works directly against the real 'sisters'
/// collection (raw Map<String, dynamic> documents) rather than a
/// strict model, since the schema has several optional/legacy fields.
///
/// NOTE: this project's schema only has two statuses in active use —
/// 'approved' and 'pending' (see admin_add_sister_screen.dart /
/// personal_information_screen.dart). There is no 'rejected' status
/// currently written anywhere, so "Reject" here sets status back to
/// 'pending' rather than a third state that nothing else recognizes.
/// If you want a real rejected state, it needs to be added to the
/// status dropdown in AdminAddSisterScreen and to ManageSistersPage's
/// filter options too.
///
/// NOTE ON ACTIVITY LOGGING: both actions now call
/// ActivityService.logActivity() directly, since this card writes to
/// Firestore via its own raw .update() calls rather than going through
/// FirestoreService.approveSister()/rejectSister() — without this,
/// approvals and rejections never showed up in RecentActivitiesCard.
class PendingProfilesCard extends StatelessWidget {
  const PendingProfilesCard({super.key});

  CollectionReference<Map<String, dynamic>> get _sistersRef =>
      FirebaseFirestore.instance.collection('sisters');

  Future<void> _approve(String uid, String fullName) async {
    await _sistersRef.doc(uid).update({'status': 'approved'});

    try {
      await ActivityService.instance.logActivity(
        type: ActivityType.sisterApproved,
        description: '${fullName.isEmpty ? 'A sister' : fullName}\'s profile was approved',
        targetSisterUid: uid,
        targetSisterName: fullName,
      );
    } catch (e) {
      debugPrint('⚠️ [PendingProfiles] Failed to log approve activity: $e');
    }
  }

  Future<void> _keepPending(BuildContext context, String uid, String fullName) async {
    // "Reject" = leave/return to pending for admin follow-up, since
    // there's no separate rejected status in this schema.
    await _sistersRef.doc(uid).update({'status': 'pending'});

    try {
      await ActivityService.instance.logActivity(
        type: ActivityType.sisterRejected,
        description: '${fullName.isEmpty ? 'A sister' : fullName}\'s profile was kept pending',
        targetSisterUid: uid,
        targetSisterName: fullName,
      );
    } catch (e) {
      debugPrint('⚠️ [PendingProfiles] Failed to log reject activity: $e');
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${fullName.isEmpty ? 'Sister' : fullName} left as pending')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      title: 'Pending Profiles',
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _sistersRef.where('status', isEqualTo: 'pending').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );
          }

          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Could not load pending profiles: ${snapshot.error}',
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No profiles awaiting review.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: docs.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.divider),
            itemBuilder: (context, index) => _buildTile(context, docs[index]),
          );
        },
      ),
    );
  }

  Widget _buildTile(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final fullName = (data['fullName'] as String?) ?? '';
    final email = (data['email'] as String?) ?? '';
    final mobile = (data['mobileNumber'] as String?) ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SisterAvatar(
            fullName: fullName,
            photoBase64: extractPhotoBase64(data),
            radius: 16,
            backgroundColor: AppColors.pending,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName.isEmpty ? 'Unnamed Sister' : fullName,
                  style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
                ),
                Text(
                  email.isNotEmpty ? email : mobile,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check_circle_outline, color: AppColors.success),
            tooltip: 'Approve',
            onPressed: () => _approve(doc.id, fullName),
          ),
          IconButton(
            icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
            tooltip: 'Keep pending',
            onPressed: () => _keepPending(context, doc.id, fullName),
          ),
        ],
      ),
    );
  }
}