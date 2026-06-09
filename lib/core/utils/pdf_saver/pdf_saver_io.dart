import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Saves base64-encoded PDF data to a local file and opens it.
Future<void> savePdfFromBase64(String dataUri, String fileName) async {
  try {
    final base64Str = dataUri.split(',').last;
    final bytes = base64Decode(base64Str);
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes);
    debugPrint('PDF saved to: ${file.path}');
  } catch (e) {
    debugPrint('Error saving PDF on IO: $e');
    rethrow;
  }
}
