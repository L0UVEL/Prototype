import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

Future<Uint8List> getFileBytes(PlatformFile file) async {
  if (file.bytes != null) return file.bytes!;
  if (file.path != null) {
    return await File(file.path!).readAsBytes();
  }
  throw Exception('Cannot read file bytes: neither bytes nor path available');
}
