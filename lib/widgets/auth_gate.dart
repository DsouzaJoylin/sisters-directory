import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/login/login_screen.dart';
import '../screens/user/profile_menu_screen.dart';
import '../services/auth_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_constants.dart';

/// Root routing widget. Listens to Firebase Auth state and shows:
/// - LoginScreen           -> when signed out
/// - AdminDashboardScreen  -> when signed in with role == 'admin'
/// - CompleteProfileScreen -> when signed in with role == 'user'
///
/// This is the single source of truth for navigation after auth
/// events, so LoginScreen/RegisterScreen never need to navigate
/// manually on success/failure.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges,
      builder: (context, authSnapshot) {
        // Still resolving the initial auth state.
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        final user = authSnapshot.data;

        // Signed out -> show login.
        if (user == null) {
          return const LoginScreen();
        }

        // Signed in -> resolve role, then route accordingly.
        return FutureBuilder<String?>(
          future: AuthService.instance.getCurrentUserRole(),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingScreen();
            }

            if (roleSnapshot.hasError) {
              return _ErrorScreen(
                message: AppConstants.genericErrorMessage,
                onRetry: () => AuthService.instance.signOut(),
              );
            }

            final role = roleSnapshot.data;

            if (role == AppConstants.roleAdmin) {
              return AdminDashboardScreen();
            }

            // Default: regular sister. No approval gate needed
            // (instant access), route straight into the app.
            return const ProfileMenuScreen();
          
          },
        );
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.largePadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Sign Out & Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}