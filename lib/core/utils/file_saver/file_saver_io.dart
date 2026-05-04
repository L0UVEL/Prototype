import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

Future<void> saveAndLaunchFile(String bytes, String fileName) async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(bytes);
    debugPrint('File saved to: ${file.path}');
  } catch (e) {
    debugPrint('Error saving file on IO: $e');
  }
}
