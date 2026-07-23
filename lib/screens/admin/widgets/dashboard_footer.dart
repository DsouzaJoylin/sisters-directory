import 'package:flutter/material.dart';

import '../../../utils/app_colors.dart';
import '../../../utils/app_constants.dart';

/// Simple footer shown at the bottom of the dashboard page —
/// app name, version placeholder, and copyright line.
class DashboardFooter extends StatelessWidget {
  const DashboardFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          const Divider(color: AppColors.divider),
          const SizedBox(height: 12),
          Text(
            '© $year ${AppConstants.appName}. All rights reserved.',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}