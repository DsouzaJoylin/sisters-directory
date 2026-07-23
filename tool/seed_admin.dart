// tool/seed_admin.dart
//
// One-off helper to mark a Firebase Auth user as an admin in Firestore.
//
// 1. Create the user first in Firebase Console -> Authentication -> Add user
//    (or sign them up in-app), and copy their UID.
// 2. Run:
//      dart run tool/seed_admin.dart <uid> <email>
//
// This requires `flutterfire configure` to have already generated
// lib/firebase_options.dart for this project.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sisters_directory/firebase_options.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    // ignore: avoid_print
    print('Usage: dart run tool/seed_admin.dart <uid> <email>');
    return;
  }

  final uid = args[0];
  final email = args[1];

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final db = FirebaseFirestore.instance;

  await db.collection('users').doc(uid).set({
    'role': 'admin',
    'email': email,
    'createdAt': FieldValue.serverTimestamp(),
  });

  // ignore: avoid_print
  print('✅ $email ($uid) is now an admin.');
}
