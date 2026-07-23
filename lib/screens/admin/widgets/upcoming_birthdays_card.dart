import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../services/dashboard_service.dart';
import '../../../utils/app_colors.dart';
import 'dashboard_card.dart';

/// Shows sisters with birthdays coming up in the next 30 days,
/// soonest first. Uses a one-time fetch (not a live stream) since
/// birthdays don't need real-time updates within a session.
///
/// Reads from DashboardService (real schema: dob string / birthMonth
/// / birthDay, with dob-string fallback for older records) rather
/// than the old SisterModel-based FirestoreService.
class UpcomingBirthdaysCard extends StatefulWidget {
  const UpcomingBirthdaysCard({super.key, this.daysAhead = 30});

  final int daysAhead;

  @override
  State<UpcomingBirthdaysCard> createState() => _UpcomingBirthdaysCardState();
}

class _UpcomingBirthdaysCardState extends State<UpcomingBirthdaysCard> {
  late Future<List<UpcomingBirthday>> _birthdaysFuture;

  @override
  void initState() {
    super.initState();
    _birthdaysFuture = DashboardService.instance
        .getUpcomingBirthdays(days: widget.daysAhead);
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      title: 'Upcoming Birthdays',
      child: FutureBuilder<List<UpcomingBirthday>>(
        future: _birthdaysFuture,
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
                'Could not load birthdays: ${snapshot.error}',
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            );
          }

          final birthdays = snapshot.data ?? [];

          if (birthdays.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No birthdays in the next ${widget.daysAhead} days.',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: birthdays.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.divider),
            itemBuilder: (context, index) {
              final birthday = birthdays[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    _BirthdayAvatar(
                      fullName: birthday.fullName,
                      photoBase64: birthday.photoBase64,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        birthday.fullName.isEmpty
                            ? 'Unnamed Sister'
                            : birthday.fullName,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      _formatDate(birthday.nextBirthday),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Small avatar for the birthdays list. Decodes the base64 photo
/// stored in documents.photoBase64 (this project doesn't use Firebase
/// Storage / photo URLs), falling back to an initial on a colored
/// circle when no photo is set or decoding fails.
class _BirthdayAvatar extends StatelessWidget {
  const _BirthdayAvatar({required this.fullName, this.photoBase64});

  final String fullName;
  final String? photoBase64;

  @override
  Widget build(BuildContext context) {
    final initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';

    ImageProvider? imageProvider;
    if (photoBase64 != null && photoBase64!.isNotEmpty) {
      try {
        imageProvider = MemoryImage(base64Decode(photoBase64!));
      } catch (_) {
        imageProvider = null;
      }
    }

    if (imageProvider == null) {
      return CircleAvatar(
        radius: 16,
        backgroundColor: AppColors.secondaryDark.withValues(alpha: 0.15),
        child: Text(
          initial,
          style: const TextStyle(
            color: AppColors.secondaryDark,
            fontWeight: FontWeight.bold,
            fontSize: 12.5,
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: 16,
      backgroundImage: imageProvider,
      backgroundColor: AppColors.secondaryDark.withValues(alpha: 0.15),
    );
  }
}