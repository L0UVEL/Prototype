import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Triggers a browser download of a base64-encoded PDF.
Future<void> savePdfFromBase64(String dataUri, String fileName) async {
  final base64Str = dataUri.split(',').last;
  final bytes = base64Decode(base64Str);
  final jsArray = bytes.toJS;
  final blob = web.Blob(
    [jsArray].toJS,
    web.BlobPropertyBag(type: 'application/pdf'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.download = fileName;
  anchor.click();
  web.URL.revokeObjectURL(url);
}
