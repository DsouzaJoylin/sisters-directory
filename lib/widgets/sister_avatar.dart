import 'dart:convert';

import 'package:flutter/material.dart';

import '../utils/app_colors.dart';

/// Shared avatar widget used everywhere a sister's photo appears
/// (directory list, search results, pending profiles, birthdays).
///
/// This project stores profile photos as base64 strings in
/// `documents.photoBase64` on the sister's Firestore document — there
/// is no Firebase Storage / photo URL in this schema. So this widget
/// decodes [photoBase64] directly with MemoryImage, rather than
/// fetching a network image. Falls back to a colored circle with the
/// sister's initial when there's no photo or it fails to decode.
class SisterAvatar extends StatelessWidget {
  const SisterAvatar({
    super.key,
    required this.fullName,
    this.photoBase64,
    this.radius = 18,
    this.backgroundColor = AppColors.primary,
  });

  final String fullName;

  /// Base64-encoded photo, typically read from a sister's
  /// `documents.photoBase64` field. Pass null/empty if the sister
  /// has no photo set.
  final String? photoBase64;

  final double radius;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';

    ImageProvider? imageProvider;
    if (photoBase64 != null && photoBase64!.isNotEmpty) {
      try {
        imageProvider = MemoryImage(base64Decode(photoBase64!));
      } catch (_) {
        // Corrupt/invalid base64 — fall back to the initial below
        // rather than crashing the whole list this avatar sits in.
        imageProvider = null;
      }
    }

    if (imageProvider == null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor.withValues(alpha: 0.15),
        child: Text(
          initial,
          style: TextStyle(
            color: backgroundColor,
            fontWeight: FontWeight.bold,
            fontSize: radius * 0.8,
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor.withValues(alpha: 0.15),
      backgroundImage: imageProvider,
    );
  }
}

/// Convenience helper for pulling photoBase64 out of a raw Firestore
/// sister document map, since it's nested under 'documents' rather
/// than being a top-level field. Use this at call sites that work
/// with Map<String, dynamic> data (most screens in this project)
/// rather than a strict model class.
String? extractPhotoBase64(Map<String, dynamic> sisterData) {
  final documents = sisterData['documents'];
  if (documents is Map) {
    final photo = documents['photoBase64'] as String?;
    if (photo != null && photo.isNotEmpty) return photo;
  }
  return null;
}