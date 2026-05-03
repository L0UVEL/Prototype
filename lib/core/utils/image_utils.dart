import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

/// Resolves a profile image string to the correct [ImageProvider].
///
/// Supports three formats:
/// - `data:image/...;base64,...` — base64-encoded image stored in Firestore
/// - `http://` or `https://` — network URL (legacy Firebase Storage URLs)
/// - Anything else — treated as a local file path (legacy, device-specific)
ImageProvider resolveProfileImage(String path) {
  if (path.startsWith('data:image')) {
    final base64Str = path.split(',').last;
    return MemoryImage(base64Decode(base64Str));
  } else if (path.startsWith('http')) {
    return NetworkImage(path);
  }
  return FileImage(File(path));
}

/// Converts an image [File] to a base64 data URI string
/// suitable for storing directly in Firestore.
Future<String> imageFileToBase64(File imageFile) async {
  final bytes = await imageFile.readAsBytes();
  final base64Str = base64Encode(bytes);
  return 'data:image/jpeg;base64,$base64Str';
}
