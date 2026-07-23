import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../services/auth_service.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_constants.dart';
import '../widgets/dashboard_card.dart';

/// Admin account settings: profile info, password reset, and
/// sign out. App-wide settings (e.g. birthday reminder window,
/// approval requirement toggle) are stubbed as placeholders
/// since there's no 'settings' Firestore document schema defined
/// yet in the project.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _handleResetPassword(BuildContext context) async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) return;

    try {
      await AuthService.instance.sendPasswordResetEmail(email);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset link sent to $email'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppConstants.genericErrorMessage),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AuthService.instance.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.largePadding),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DashboardCard(
              title: 'Account',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Name', user?.displayName ?? '—'),
                  const SizedBox(height: 10),
                  _buildInfoRow('Email', user?.email ?? '—'),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _handleResetPassword(context),
                    icon: const Icon(Icons.lock_reset_outlined, size: 18),
                    label: const Text('Send Password Reset Email'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            DashboardCard(
              title: 'Directory Preferences',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: false,
                    onChanged: null, // placeholder — needs a settings doc/service
                    title: const Text('Require admin approval for new sisters'),
                    subtitle: const Text(
                      'Currently off — new registrations get instant access',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    activeThumbColor: AppColors.primary,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'More preferences (birthday reminder window, default '
                    'community list, etc.) can be added here once a '
                    "settings' Firestore document is defined.",
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            DashboardCard(
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmSignOut(context),
                  icon: const Icon(Icons.logout, size: 18, color: AppColors.error),
                  label: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      ],
    );
  }
}