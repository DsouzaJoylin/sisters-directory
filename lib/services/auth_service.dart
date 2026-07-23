import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../utils/app_constants.dart';

/// Handles all Firebase Authentication logic (sign up, sign in,
/// sign out, password reset) and keeps the corresponding user
/// document in Firestore in sync.
class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream of auth state changes — used by AuthGate to decide
  /// which screen to show (login vs dashboard).
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Currently signed-in Firebase user, if any.
  User? get currentUser => _auth.currentUser;

  /// Registers a new sister with email/password and creates
  /// their corresponding Firestore user document.
  ///
  /// IMPORTANT: the Firestore security rules only allow a
  /// newly-created user to create their OWN users/{uid} doc when
  /// role == 'sister' — this is intentional, so a brand-new user
  /// can never self-assign an admin role. This value must match
  /// the rules exactly, or the write below is silently rejected
  /// with permission-denied.
  ///
  /// If the Firestore write fails for any reason, we roll back by
  /// deleting the just-created Auth user. Without this rollback, a
  /// failed profile write leaves an orphaned Auth account behind —
  /// the email is "used" but the person has no working profile, so
  /// every retry incorrectly fails with email-already-in-use.
  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) async {
    UserCredential? credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw Exception('Registration failed: no user returned.');
      }

      // Optional: set the Firebase Auth display name too.
      await user.updateDisplayName(fullName.trim());

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .set({
        AppConstants.fieldUid: user.uid,
        'fullName': fullName.trim(),
        AppConstants.fieldEmail: email.trim(),
        // Must be 'sister' to satisfy the Firestore rule that lets a
        // new user create their own doc. Do NOT use
        // AppConstants.roleUser here unless it is also 'sister'.
        AppConstants.fieldRole: 'sister',
        AppConstants.fieldStatus: AppConstants.statusApproved,
        AppConstants.fieldCreatedAt: FieldValue.serverTimestamp(),
      });

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    } catch (e) {
      // Covers Firestore errors (e.g. permission-denied) and anything
      // else that goes wrong after the Auth account was created.
      // Roll back the orphaned Auth account so the person can retry
      // with the same email instead of hitting a false
      // "email-already-in-use" on their next attempt.
      if (credential?.user != null) {
        try {
          await credential!.user!.delete();
        } catch (_) {
          // If rollback itself fails (e.g. requires-recent-login),
          // there's nothing more we can do client-side; the original
          // error below is still the useful one to surface.
        }
      }
      throw Exception(
          'Could not complete registration. Please try again. ($e)');
    }
  }

  /// Signs an existing user in with email/password.
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  /// Sends a password reset email.
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  /// Signs the current user out.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Fetches the role ('admin' or 'sister') for the currently
  /// signed-in user from Firestore. Returns null if not found.
  Future<String?> getCurrentUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(user.uid)
        .get();

    if (!doc.exists) return null;
    return doc.data()?[AppConstants.fieldRole] as String?;
  }

  /// Fetches the full user document for the currently signed-in user.
  Future<Map<String, dynamic>?> getCurrentUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(user.uid)
        .get();

    return doc.data();
  }

  /// Maps Firebase's raw error codes to friendly, user-facing
  /// messages defined in AppConstants.
  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return AppConstants.emailInUseMessage;
      case 'invalid-email':
        return AppConstants.invalidEmailMessage;
      case 'weak-password':
        return AppConstants.weakPasswordMessage;
      case 'user-not-found':
        return AppConstants.userNotFoundMessage;
      case 'wrong-password':
      case 'invalid-credential':
        return AppConstants.wrongPasswordMessage;
      case 'network-request-failed':
        return AppConstants.networkErrorMessage;
      default:
        return e.message ?? AppConstants.genericErrorMessage;
    }
  }
}