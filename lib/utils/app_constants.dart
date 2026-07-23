/// App-wide constants: strings, durations, sizes, Firestore
/// collection names, and validation rules. Centralizing these
/// avoids magic strings/numbers scattered across the codebase.
class AppConstants {
  AppConstants._(); // prevent instantiation

  // App info
  static const String appName = 'Sisters Directory';
  static const String appTagline = 'Connecting our community, one sister at a time';

  // Firestore collection names
  static const String usersCollection = 'users';
  static const String sistersCollection = 'sisters';
  static const String activitiesCollection = 'activities';
  static const String settingsCollection = 'settings';

  // Firestore field names (auth/user related)
  static const String fieldEmail = 'email';
  static const String fieldRole = 'role';
  static const String fieldStatus = 'status';
  static const String fieldCreatedAt = 'createdAt';
  static const String fieldUid = 'uid';

  // Roles
  static const String roleAdmin = 'admin';
  static const String roleUser = 'user';

  // Profile / membership status
  static const String statusPending = 'pending';
  static const String statusApproved = 'approved';
  static const String statusRejected = 'rejected';

  // Validation rules
  static const int minPasswordLength = 6;
  static const int maxNameLength = 60;
  static final RegExp emailRegex =
      RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  static final RegExp phoneRegex = RegExp(r'^[0-9]{10}$');

  // UI sizing
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double borderRadius = 12.0;
  static const double buttonHeight = 50.0;

  // Animation / feedback durations
  static const Duration snackBarDuration = Duration(seconds: 3);
  static const Duration splashDelay = Duration(seconds: 2);

  // Error messages
  static const String genericErrorMessage =
      'Something went wrong. Please try again.';
  static const String networkErrorMessage =
      'No internet connection. Please check your network.';
  static const String weakPasswordMessage =
      'Password should be at least 6 characters.';
  static const String emailInUseMessage =
      'An account already exists with this email.';
  static const String invalidEmailMessage =
      'Please enter a valid email address.';
  static const String userNotFoundMessage =
      'No account found with this email.';
  static const String wrongPasswordMessage =
      'Incorrect password. Please try again.';
}