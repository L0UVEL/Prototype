import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

Future<Uint8List> getFileBytes(PlatformFile file) async {
  if (file.bytes != null) return file.bytes!;
  throw UnimplementedError('File bytes not available on this platform');
}
