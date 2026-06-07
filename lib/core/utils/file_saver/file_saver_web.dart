import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<void> saveAndLaunchFile(String content, String fileName) async {
  final bytes = utf8.encode(content);
  final jsArray = bytes.toJS;
  final blob = web.Blob([jsArray].toJS);
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.download = fileName;
  anchor.click();
  web.URL.revokeObjectURL(url);
}
