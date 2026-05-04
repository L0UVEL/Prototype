import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

Future<List<Map<String, dynamic>>> listHealthReports() async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    if (directory.existsSync()) {
      final files = directory.listSync().where((file) {
        return file.path.endsWith('.csv') &&
            file.path.contains('Student_Health_Report');
      }).toList();

      files.sort((a, b) {
        return (b as File).lastModifiedSync().compareTo((a as File).lastModifiedSync());
      });

      return files.map((file) => {
        'path': file.path,
        'name': file.uri.pathSegments.last,
        'modified': (file as File).lastModifiedSync(),
        'entity': file,
      }).toList();
    }
  } catch (e) {
    debugPrint('Error listing reports: $e');
  }
  return [];
}

Future<void> exportHealthReport(FileSystemEntity file) async {
  try {
    final filename = file.uri.pathSegments.last;
    String newPath;

    if (Platform.isAndroid) {
      newPath = '/storage/emulated/0/Download/$filename';
    } else {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) {
        newPath = '${downloadsDir.path}${Platform.pathSeparator}$filename';
      } else {
        debugPrint('Downloads directory not available');
        return;
      }
    }

    final bytes = await (file as File).readAsBytes();
    await File(newPath).writeAsBytes(bytes);
    debugPrint('Exported to: $newPath');
  } catch (e) {
    debugPrint('Error exporting report: $e');
  }
}
