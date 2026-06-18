import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/services/announcement_service.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/utils/pdf_saver/pdf_saver.dart';
import 'pdf_viewer_screen.dart';

class AnnouncementDetailScreen extends StatefulWidget {
  final String announcementId;

  const AnnouncementDetailScreen({super.key, required this.announcementId});

  @override
  State<AnnouncementDetailScreen> createState() =>
      _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState extends State<AnnouncementDetailScreen> {
  List<PdfAttachment>? _loadedPdfs;
  bool _loadingPdfs = false;

  @override
  void initState() {
    super.initState();
    _loadPdfs();
  }

  Future<void> _loadPdfs() async {
    setState(() => _loadingPdfs = true);
    try {
      final pdfs = await context
          .read<AnnouncementService>()
          .loadPdfAttachments(widget.announcementId);
      if (mounted) {
        setState(() {
          _loadedPdfs = pdfs;
          _loadingPdfs = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading PDF attachments: $e');
      if (mounted) setState(() => _loadingPdfs = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final announcementService = context.watch<AnnouncementService>();
    final announcement =
        announcementService.getAnnouncement(widget.announcementId);

    if (announcement == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Announcement not found')),
        body: const Center(child: Text('Announcement not found')),
      );
    }

    // Use loaded subcollection PDFs, fall back to inline (legacy) PDFs
    final pdfsToShow = _loadedPdfs != null && _loadedPdfs!.isNotEmpty
        ? _loadedPdfs!
        : announcement.pdfAttachments;

    return Scaffold(
      appBar: AppBar(title: const Text('Announcement')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              announcement.title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat(
                'EEEE, MMMM d, y • h:mm a',
              ).format(announcement.timestamp),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            if (announcement.imageUrls.isNotEmpty) ...[
              for (final path in announcement.imageUrls) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image(
                    image: resolveProfileImage(path),
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 200,
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 8),
            ],
            Text(
              announcement.content,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            // ─── PDF Attachments Section ───
            if (_loadingPdfs) ...[
              const SizedBox(height: 24),
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              ),
            ] else if (pdfsToShow.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                'Attachments',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...pdfsToShow.map((pdf) {
                return _PdfAttachmentCard(pdf: pdf);
              }),
            ],
            const SizedBox(height: 32),
            const Divider(),
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'Posted by Admin',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card widget for a single PDF attachment with view & download actions.
class _PdfAttachmentCard extends StatefulWidget {
  final PdfAttachment pdf;

  const _PdfAttachmentCard({required this.pdf});

  @override
  State<_PdfAttachmentCard> createState() => _PdfAttachmentCardState();
}

class _PdfAttachmentCardState extends State<_PdfAttachmentCard> {
  bool _downloading = false;

  void _viewPdf() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PdfViewerScreen(pdf: widget.pdf),
      ),
    );
  }

  Future<void> _downloadPdf() async {
    setState(() => _downloading = true);
    try {
      await savePdfFromBase64(widget.pdf.dataUri, widget.pdf.name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Downloaded: ${widget.pdf.name}',
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: _viewPdf,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 6,
          ),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF800000).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.picture_as_pdf,
              color: Color(0xFF800000),
              size: 24,
            ),
          ),
          title: Text(
            widget.pdf.name,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Row(
              children: [
                Icon(Icons.visibility, size: 14, color: Colors.grey),
                SizedBox(width: 4),
                Text(
                  'Tap to view',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          trailing: _downloading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.download_rounded,
                        color: Color(0xFF800000),
                      ),
                      tooltip: 'Download PDF',
                      onPressed: _downloadPdf,
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: Colors.grey,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
