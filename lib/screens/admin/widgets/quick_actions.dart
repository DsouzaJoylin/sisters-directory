import 'package:flutter/material.dart';

import '../../../utils/app_colors.dart';
import '../../../utils/app_constants.dart';
import 'dashboard_card.dart';

/// Row of shortcut buttons for common admin tasks (add sister,
/// review pending, view reports). Uses simple callbacks so the
/// parent DashboardPage controls navigation between admin pages.
class QuickActions extends StatelessWidget {
  const QuickActions({
    super.key,
    required this.onAddSister,
    required this.onManageSisters,
    required this.onViewReports,
  });

  final VoidCallback onAddSister;
  final VoidCallback onManageSisters;
  final VoidCallback onViewReports;

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      title: 'Quick Actions',
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _ActionButton(
            icon: Icons.person_add_alt_outlined,
            label: 'Add Sister',
            color: AppColors.primary,
            onTap: onAddSister,
          ),
          _ActionButton(
            icon: Icons.groups_outlined,
            label: 'Manage Sisters',
            color: AppColors.info,
            onTap: onManageSisters,
          ),
          _ActionButton(
            icon: Icons.bar_chart_outlined,
            label: 'View Reports',
            color: AppColors.secondaryDark,
            onTap: onViewReports,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}