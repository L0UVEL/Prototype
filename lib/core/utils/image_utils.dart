import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'file_image_helper_stub.dart'
    if (dart.library.io) 'file_image_helper_io.dart';

/// Resolves a profile image string to the correct [ImageProvider].
///
/// Supports three formats:
/// - `data:image/...;base64,...` — base64-encoded image stored in Firestore
/// - `http://` or `https://` — network URL (legacy Firebase Storage URLs)
/// - Anything else — treated as a local file path (legacy, device-specific)
ImageProvider resolveProfileImage(String path) {
  if (path.isEmpty) return const AssetImage('assets/launcher_icon.png');
  
  if (path.startsWith('data:image')) {
    final base64Str = path.split(',').last;
    return MemoryImage(base64Decode(base64Str));
  } else if (path.startsWith('http')) {
    return NetworkImage(path);
  }
  
  if (kIsWeb) {
    // Web doesn't support local file paths via FileImage
    return const AssetImage('assets/launcher_icon.png'); // Fallback
  }
  
  return getFileImage(path);
}

/// Converts an [XFile] to a base64 data URI string.
/// Works on both mobile and web.
Future<String> xFileToBase64(XFile xFile) async {
  final bytes = await xFile.readAsBytes();
  final base64Str = base64Encode(bytes);
  return 'data:image/jpeg;base64,$base64Str';
}
