import 'package:flutter/material.dart';
import '../../../core/services/announcement_service.dart';
import '../../../core/utils/pdf_saver/pdf_saver.dart';
import '../widgets/pdf_viewer_widget.dart';

/// Full-screen PDF viewer that renders the PDF inline in the app.
class PdfViewerScreen extends StatelessWidget {
  final PdfAttachment pdf;

  const PdfViewerScreen({super.key, required this.pdf});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          pdf.name,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Download PDF',
            onPressed: () async {
              try {
                await savePdfFromBase64(pdf.dataUri, pdf.name);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Downloaded: ${pdf.name}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: const Color(0xFF4CAF50),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error downloading PDF: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: PdfViewerWidget(
        dataUri: pdf.dataUri,
        fileName: pdf.name,
      ),
    );
  }
}
