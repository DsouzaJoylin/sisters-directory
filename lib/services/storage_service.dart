import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

/// Handles Firebase Storage uploads for sister profile photos.
/// Takes raw bytes (Uint8List) rather than a dart:io File — File
/// isn't available on Flutter Web at all, and both callers of
/// this service (add_sister_page.dart for admin-added sisters,
/// complete_profile_screen.dart for self-registered sisters) need
/// to work on web since this app runs via `flutter run -d chrome`.
///
/// NOTE: this file was reconstructed from the two call sites that
/// reference it (uploadSisterPhoto(uid:, bytes:) returning a
/// download URL). If your original storage_service.dart had
/// additional methods (e.g. deletePhoto, photo compression, a
/// separate upload path for admin-added vs self-registered
/// sisters), merge those back in — this only covers what the
/// current callers actually need.
class StorageService {
  StorageService._internal();
  static final StorageService instance = StorageService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads a sister's profile photo to
  /// `sister_photos/{uid}.jpg` and returns its public download URL.
  /// Overwrites any existing photo at that path (same uid = same
  /// file path), so re-uploading effectively replaces the old photo.
  Future<String> uploadSisterPhoto({
    required String uid,
    required Uint8List bytes,
  }) async {
    final ref = _storage.ref('sister_photos/$uid.jpg');

    await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    return ref.getDownloadURL();
  }

  /// Deletes a sister's profile photo, if one exists. Safe to call
  /// even if no photo was ever uploaded — silently does nothing.
  Future<void> deleteSisterPhoto(String uid) async {
    try {
      await _storage.ref('sister_photos/$uid.jpg').delete();
    } on FirebaseException catch (e) {
      // object-not-found just means there was nothing to delete.
      if (e.code != 'object-not-found') rethrow;
    }
  }
}