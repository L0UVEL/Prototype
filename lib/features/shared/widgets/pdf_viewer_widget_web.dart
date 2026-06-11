import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'dart:ui_web' as ui_web;

/// Web implementation: renders the PDF inside an <iframe> using a Blob URL.
class PdfViewerWidget extends StatefulWidget {
  final String dataUri;
  final String fileName;

  const PdfViewerWidget({
    super.key,
    required this.dataUri,
    required this.fileName,
  });

  @override
  State<PdfViewerWidget> createState() => _PdfViewerWidgetState();
}

class _PdfViewerWidgetState extends State<PdfViewerWidget> {
  late final String _viewType;
  String? _blobUrl;

  @override
  void initState() {
    super.initState();
    _viewType = 'pdf-viewer-${widget.dataUri.hashCode}-${DateTime.now().millisecondsSinceEpoch}';
    _registerView();
  }

  void _registerView() {
    try {
      // Decode the base64 data URI to bytes
      final base64Str = widget.dataUri.split(',').last;
      final bytes = base64Decode(base64Str);
      final jsArray = bytes.toJS;
      final blob = web.Blob(
        [jsArray].toJS,
        web.BlobPropertyBag(type: 'application/pdf'),
      );
      _blobUrl = web.URL.createObjectURL(blob);

      // Register a platform view factory
      ui_web.platformViewRegistry.registerViewFactory(
        _viewType,
        (int viewId, {Object? params}) {
          final iframe =
              web.document.createElement('iframe') as web.HTMLIFrameElement;
          iframe.src = _blobUrl!;
          iframe.style.border = 'none';
          iframe.style.width = '100%';
          iframe.style.height = '100%';
          return iframe;
        },
      );
    } catch (e) {
      debugPrint('Error setting up PDF viewer: $e');
    }
  }

  @override
  void dispose() {
    if (_blobUrl != null) {
      web.URL.revokeObjectURL(_blobUrl!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_blobUrl == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Unable to load PDF',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return HtmlElementView(viewType: _viewType);
  }
}
